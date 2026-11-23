package com.smarthome.task;

import com.smarthome.config.HuaweiIoTProperties;
import com.smarthome.service.HuaweiSyncService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.qpid.jms.JmsConnection;
import org.apache.qpid.jms.JmsConnectionFactory;
import org.apache.qpid.jms.JmsConnectionExtensions;
import org.apache.qpid.jms.JmsConnectionListener;
import org.apache.qpid.jms.JmsQueue;
import org.apache.qpid.jms.transports.TransportOptions;
import org.apache.qpid.jms.transports.TransportSupport;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

import javax.jms.Connection;
import javax.jms.Message;
import javax.jms.MessageConsumer;
import javax.jms.Session;
import java.net.InetAddress;
import java.net.URI;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * 华为云 IoTDA AMQP 订阅客户端（实时推送，2026-11-19 新增）。
 *
 * <p>【为什么用推送】原来的 3 秒轮询每次都是完整的 HTTPS 请求（建连 + token + 响应），
 * 设备每 3 秒上报一次，一天就是 28800 次无意义轮询。AMQP 是一条长连接：
 * <ul>
 *   <li>平台在设备上报的瞬间把报文推过来，秒级到达（设备本来就是每 3 秒上报一次，
 *       所以实际延迟上限就是 3 秒——与轮询一样，但轮询还有最多 3 秒的相位差）</li>
 *   <li>设备不上报时连接上没有流量，服务器零请求压力</li>
 *   <li>failover 参数自带断线自动重连，重连间隔 3~30 秒指数退避</li>
 * </ul>
 *
 * <p>【连接参数】（来源：华为云 IoTDA《Java SDK 接入示例》官方 demo）
 * <ul>
 *   <li>地址：amqps://{应用侧域名}:5671，amqp.vhost=default，SASL PLAIN</li>
 *   <li>用户名：accessKey={accessKey}|timestamp={毫秒时间戳}（时间戳防止重放）</li>
 *   <li>密码：accessCode</li>
 *   <li>队列：DefaultQueue（设备数据默认队列）</li>
 * </ul>
 *
 * <p>【启用条件】props.isAmqpReady() 为 false（没配 AMQP 凭证）时本类不启动，
 * 上行退回 HuaweiSyncTask 的 3 秒轮询——两种模式互斥，配哪个用哪个。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class HuaweiAmqpClient implements ApplicationRunner {

    private final HuaweiIoTProperties props;
    private final HuaweiSyncService syncService;

    /** 报文处理线程池：onMessage 里不能做耗时操作（否则心跳超时被平台断开） */
    private final ExecutorService worker = Executors.newFixedThreadPool(2);

    private volatile boolean started = false;

    @Override
    public void run(ApplicationArguments args) {
        if (!props.isReady()) {
            return;             // 凭证都没配，纯模拟模式
        }
        if (!props.isAmqpReady()) {
            log.info("[华为云] 未配置 AMQP 凭证，上行走 3 秒轮询（HuaweiSyncTask）");
            return;
        }
        try {
            start();
            started = true;
        } catch (Exception e) {
            log.error("[华为云] AMQP 订阅启动失败，上行退回轮询模式：{}", e.getMessage(), e);
        }
    }

    /** 建立 AMQP 连接并订阅设备数据队列。 */
    private void start() throws Exception {
        String clientId = safeClientId();

        // 1) 连接 URL：failover 包一层获得自动重连能力
        String url = "failover:(amqps://" + props.getAmqpHost() + ":5671"
                + "?amqp.vhost=default&amqp.idleTimeout=8000&amqp.saslMechanisms=PLAIN)"
                + "?jms.clientID=" + clientId
                + "&jms.prefetchPolicy.queuePrefetch=100"
                + "&failover.reconnectDelay=3000"
                + "&failover.maxReconnectDelay=30000";

        JmsConnectionFactory cf = new JmsConnectionFactory(url);
        TransportOptions transport = new TransportOptions();
        transport.setTrustAll(true);
        cf.setSslContext(TransportSupport.createJdkSslContext(transport));

        // 2) 用户名：accessKey=xxx|timestamp=yyy（IoTDA 固定格式，时间戳防重放）
        String userName = "accessKey=" + props.getAmqpAccessKey();
        cf.setExtension(JmsConnectionExtensions.USERNAME_OVERRIDE.toString(), (connection, uri) ->
                userName + "|timestamp=" + System.currentTimeMillis());

        // 3) 建连、会话、消费者
        Connection connection = cf.createConnection(userName, props.getAmqpAccessCode());
        ((JmsConnection) connection).addConnectionListener(listener);
        Session session = connection.createSession(false, Session.AUTO_ACKNOWLEDGE);
        connection.start();
        MessageConsumer consumer = session.createConsumer(new JmsQueue(props.getAmqpQueueName()));

        // 4) 收到报文交给线程池异步处理，onMessage 本身保持轻量
        consumer.setMessageListener(message -> {
            try {
                String body = message.getBody(String.class);
                worker.submit(() -> syncService.handlePushMessage(body));
            } catch (Exception e) {
                log.warn("[华为云] 推送报文接收异常：{}", e.getMessage());
            }
        });

        log.info("[华为云] AMQP 订阅已建立（推送模式）：host={} queue={} clientId={}，"
                        + "设备上报后秒级到达，轮询已停用",
                props.getAmqpHost(), props.getAmqpQueueName(), clientId);
    }

    /** 控制台"消费组状态"页会显示 clientId，用本机标识便于区分客户端 */
    private String safeClientId() {
        try {
            return InetAddress.getLocalHost().getHostAddress() + "-smarthome";
        } catch (Exception e) {
            return UUID.randomUUID().toString();
        }
    }

    /** 连接状态监听：只打日志，重连由 failover 层自动完成 */
    private final JmsConnectionListener listener = new JmsConnectionListener() {
        @Override
        public void onConnectionEstablished(URI remoteURI) {
            log.info("[华为云] AMQP 连接已建立 {}", remoteURI);
        }

        @Override
        public void onConnectionFailure(Throwable error) {
            log.error("[华为云] AMQP 连接失败：{}", error.getMessage());
        }

        @Override
        public void onConnectionInterrupted(URI remoteURI) {
            log.warn("[华为云] AMQP 连接中断，自动重连中… {}", remoteURI);
        }

        @Override
        public void onConnectionRestored(URI remoteURI) {
            log.info("[华为云] AMQP 连接已恢复 {}", remoteURI);
        }

        @Override
        public void onInboundMessage(org.apache.qpid.jms.message.JmsInboundMessageDispatch envelope) {
        }

        @Override
        public void onSessionClosed(javax.jms.Session session, Throwable cause) {
        }

        @Override
        public void onConsumerClosed(MessageConsumer consumer, Throwable cause) {
        }

        @Override
        public void onProducerClosed(javax.jms.MessageProducer producer, Throwable cause) {
        }
    };

    public boolean isStarted() {
        return started;
    }
}
