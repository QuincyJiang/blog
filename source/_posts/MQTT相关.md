title: mac搭建Pyqt5环境
date: 2017/12/11 20:30:50
categories: MQTT
comments: true
tags: [mqtt]
---
# MQTT相关
MQTT官网：[http://mqtt.org/](http://mqtt.org/)

MQTT介绍：[http://www.ibm.com](http://www.ibm.com)

MQTT Android github：[https://github.com/eclipse/paho.mqtt.android](https://github.com/eclipse/paho.mqtt.android)

MQTT API：[http://www.eclipse.org/paho/files/javadoc/index.html](http://www.eclipse.org/paho/files/javadoc/index.html)

MQTT Android API： [http://www.eclipse.org/paho/files/android-javadoc/index.html](http://www.eclipse.org/paho/files/android-javadoc/index.html)

----------
## MQTT服务器搭建 
- 环境：windows7 64位
- JAVA环境:jdk 1.8.0
- 下载：[Apollo服务器](http://activemq.apache.org/apollo/download.html)

以下为步骤：
1. 下载Apollo服务器后，解压安装；
2. 用命令行进入到安装目录bin目录下
3. 输入 apollo create xxx (xxx为服务器实例名，eg.apollo create xmaihh)
>执行之后会在bin目录下创建名称为xxx的文件夹，比如我生成的文件夹是 xmaihh
xxx文件夹下etc\apollo.xml文件是 配置服务器文件信息
etc\users.properties文件包含连接MQTT服务器时用到的用户名和密码，默认为admin=password，即账号为admin，密码为password，可自行更改。
4. 用命令行进入到刚创建的xxx\bin目录下，输入apollo-broker.cmd run开启服务器
5. 在浏览器输入http://127.0.0.1:61680/，查看是否安装成功
![](https://i.imgur.com/qyuQDHy.png)
![](https://i.imgur.com/SAh5lfp.png)
![](https://i.imgur.com/5KZpNcP.png)
## MQTT Android客户端
- 环境：AndroidStudio 3.0.1
- topic：中文意思是“话题”。在MQTT中订阅了(subscribe)同一话题（topic）的客户端会同时收到消息推送。
- clientId：客户身份唯一标识。
- qos：服务质量。
- retained：要保留最后的断开连接信息。
- MqttAndroidClient#subscribe()：订阅某个话题。
- MqttAndroidClient#publish()： 向某个话题发送消息，之后服务器会推送给所有订阅了此话题的客户。
- userName：连接到MQTT服务器的用户名。
- passWord ：连接到MQTT服务器的密码

以下为步骤：
1. 添加依赖
```
repositories {
    maven {
        url "https://repo.eclipse.org/content/repositories/paho-snapshots/"
    }
}
dependencies {
    compile 'org.eclipse.paho:org.eclipse.paho.client.mqttv3:1.1.0'
    compile 'org.eclipse.paho:org.eclipse.paho.android.service:1.1.1'
}
```
2. 添加权限
```
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
```
3. 注册Service
```
    <!-- Mqtt Service -->
    <service android:name="org.eclipse.paho.android.service.MqttService" />
```
4. 具体实现

```
/**
 * MQTT长连接服务
 */
public class MQTTService extends Service {
    public static final String TAG = MQTTService.class.getSimpleName();

    public static MqttAndroidClient client;
    private MqttConnectOptions connectOptions;
        private String host = "tcp://192.168.102.216:61613";
//        private String host = "tcp://192.168.8.241:61613";
//        private String host = "tcp://10.0.2.2:61613";
//    private String host = "tcp://192.168.26.144:1883";

    private String username = "admin";
    private String password = "password";
    private static String myTopic = "topic";
    private String clientId = "test123";

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        init();
        return super.onStartCommand(intent, flags, startId);
    }
    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    public static void publish(String msg) {
        String topic = myTopic;
        Integer qos = 0;
        Boolean retained = false;
        try {
            client.publish(topic, msg.getBytes(), qos.intValue(), retained.booleanValue());
        } catch (MqttException e) {
            e.printStackTrace();
        }
    }
    /**
     * 初始化方法
     */
    private void init() {
        // 服务器地址 (协议+地址+端口号)
        String url = host;
        client = new MqttAndroidClient(this, url, clientId);
        client.setCallback(mqttCallback);
        connectOptions = new MqttConnectOptions();
        // 清除缓存
        connectOptions.setCleanSession(true);
        // 设置超时时间,单位:秒
        connectOptions.setConnectionTimeout(10);
        // 心跳包发送时间间隔,单位:秒
        connectOptions.setKeepAliveInterval(20);
        // 用户名
        connectOptions.setUserName(username);
        // 密码
        connectOptions.setPassword(password.toCharArray());
        // last will message
        boolean doConnect = true;
        String message = "{\"terminal_uid\":\"" + clientId + "\"}";
        String topic = myTopic;
        Integer qos = 0;
        Boolean retained = false;
        if ((!message.equals("")) || (!topic.equals(""))) {
            //最后的遗嘱
            try {
                connectOptions.setWill(topic, message.getBytes(), qos.intValue(), retained.booleanValue());
            } catch (Exception ex) {
                Log.d(TAG, "Exception Occured", ex);
                doConnect = false;
                iMqttActionListener.onFailure(null, ex);
            }
        }

        if (doConnect) {
            //连接MQTT服务器
            doClientConnection();
        }
    }

    /**
     * 连接MQTT服务器
     */
    private void doClientConnection() {
        if (!client.isConnected() && isConnectIsNomarl()) {
            try {
                client.connect(connectOptions, null, iMqttActionListener);
            } catch (MqttException e) {
                e.printStackTrace();
            }
        }
    }

    /**
     * 判断网络是否连接
     *
     * @return
     */
    private boolean isConnectIsNomarl() {
        ConnectivityManager connectivityManager = (ConnectivityManager)
                this.getApplicationContext().getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo info = connectivityManager.getActiveNetworkInfo();
        if (info != null && info.isAvailable()) {
            String name = info.getTypeName();
            Log.i(TAG, "MQTT当前网络名称：" + name);
            return true;
        } else {
            Log.i(TAG, "MQTT 没有可用网络");
            return false;
        }
    }

    /**
     * MQTT监听并且接收消息
     */
    private MqttCallback mqttCallback = new MqttCallback() {
        @Override
        public void connectionLost(Throwable cause) {
            //失去连接，重连
        }

        @Override
        public void messageArrived(String topic, MqttMessage message) throws Exception {
            EventBus.getDefault().post(message);
            String str2 = topic + ";qos :" + message.getQos() + ";retained:" + message.isRetained();
            Log.d(TAG, "messageArrived: str2" + str2);
        }

        @Override
        public void deliveryComplete(IMqttDeliveryToken token) {

        }
    };
    /**
     * MQTT是否连接成功
     */
    private IMqttActionListener iMqttActionListener = new IMqttActionListener() {
        @Override
        public void onSuccess(IMqttToken asyncActionToken) {
            Log.d(TAG, "onSuccess: MQTT连接成功");
            try {
                //订阅myTopic话题
                client.subscribe(myTopic, 1);
            } catch (MqttException e) {
                e.printStackTrace();
            }
        }

        @Override
        public void onFailure(IMqttToken asyncActionToken, Throwable exception) {
            exception.printStackTrace();
            //连接失败，重连
        }
    };

}
```
>初始化各个参数，之后连接服务器。连接成功之后在http://127.0.0.1:61680/ 看到自动创建了名称为”topic”的topic。这里我使用两台真机。http://127.0.0.1:61680/ 服务端看到的是这个样子
![](https://i.imgur.com/9eB33fT.png)
1. 模拟器运行的时候host = "tcp://10.0.2.2:61613"，因为10.0.2.2 是模拟器设置的特定ip，是你电脑的别名。真机运行的时候host = "tcp://192.168.102.216:61613"。192.168.102.216是我主机的IPv4地址，查看本机IP的cmd命令为ipconfig/all。 
2. 两次运行时的clientId不能一样（为了保证客户标识的唯一性）




----------
### 访问管理界面
要修改前面创建的xxx文件夹下etc\apollo.xml文件，添加你的host就可以通过host访问管理界面，否则只能通过 http://127.0.0.1:61680 和 https://127.0.0.1:61681 访问
```
... ...
 <virtual_host id="xmaihh">
    <!--
      You should add all the host names that this virtual host is known as
      to properly support the STOMP 1.1 virtual host feature.
      -->
    <host_name>xmaihh</host_name>
    <host_name>localhost</host_name>
    <host_name>127.0.0.1</host_name>
	<!--以下为添加内容-->
    <host_name>192.168.102.216</host_name>
	<!--以上为添加内容-->
    <!-- Uncomment to disable security for the virtual host -->
    <!-- <authentication enabled="false"/> -->

    <!-- Uncomment to disable security for the virtual host -->
    <!-- <authentication enabled="false"/> -->
    <access_rule allow="users" action="connect create destroy send receive consume"/>


    <!-- You can delete this element if you want to disable persistence for this virtual host -->
    <leveldb_store directory="${apollo.base}/data"/>


  </virtual_host>

  <web_admin bind="http://127.0.0.1:61680"/>
  <web_admin bind="https://127.0.0.1:61681"/>
  <!--以下为添加内容-->
  <web_admin bind="http://192.168.102.216:61680"/>
  <web_admin bind="https://192.168.102.216:61681"/>
  <!--以上为添加内容-->

  <connector id="tcp" bind="tcp://0.0.0.0:61613" connection_limit="2000"/>
  <connector id="tls" bind="tls://0.0.0.0:61614" connection_limit="2000"/>
  <connector id="ws"  bind="ws://0.0.0.0:61623"  connection_limit="2000"/>
  <connector id="wss" bind="wss://0.0.0.0:61624" connection_limit="2000"/>

  <key_storage file="${apollo.base}/etc/keystore" password="password" key_password="password"/>
```