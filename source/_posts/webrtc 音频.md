title: webrtc音频总结
date: 2017/08/16 21:10:30
categories: webrtc
comments: true
tags: [webrtc]
---

webrtc/modules/audio_device/android/audio_record_jni.cc

这个文件，是音频采集jni类文件。




Android Audio Record 和 JNI 通信接口包括：

```
// java 调用 c++ 接口
nativeCacheDirectBufferAddress
nativeDataIsRecorded

```

```
// c++ 回调 java 接口
initRecording
startRecording
stopRecording
enableBuiltInAEC
enableBuiltInNS

```

nativeCacheDirectBufferAddress 和 nativeDataIsRecorded 只是为了高效的将 AudioRecord 采集到的音频数据传递给 native。




# WebRtcVoiceEngine 

WebRtcVoiceEngine 初始化

```
WebRtcVoiceEngine::Init(){
    send_codecs_ = CollectCodecs(encoder_factory_->GetSupportedEncoders());
    recv_codecs_ = CollectCodecs(decoder_factory_->GetSupportedDecoders());

    adm_ = webrtc::AudioDeviceModule::Create(
        webrtc::AudioDeviceModule::kPlatformDefaultAudio
    );

    webrtc::adm_helpers::Init(adm());
    webrtc::apm_helpers::Init(apm());


}
```

可知，WebRtcVoiceEngine 里面的 adm_ 就是 AudioDeviceModule ，代码在 /modules/audio_device/audio_device_impl.cc


在 webrtcvoiceengine.h
```
// WebRtcVoiceEngine

//public 
void Init();
AudioState GetAudioState();
VoiceMediaChannel* CreateChannel(Call call, MediaConfig config, AudioOptions options);
AudioCodec send_codecs();
AudioCodec recv_codecs();
RtpCapabilities GetCapabilities();

void RegisterChannel(WebRtcVoiceMediaChannel* channel);
void UnregisterChannel(WebRtcVoiceMediaChannel* channel);

bool StartAecDump();
void StopAecDump();

//private
AudioDeviceModule adm_;
AudioEncoderFactory encoder_factory_;
AudioDecoderFactory decoder_factory_;
AudioMixer audio_mixer_;
AudioProcessing apm_;
AudioState audio_state_;
AudioCodec send_codecs_;
AudioCodec recv_codecs_;

WebRtcVoiceMediaChannel channels_;
```



## audio_device

//webrtc/modules/audio_device/

audio_device_impl.cc

```
AudioDeviceModule::Create(){
    audioDevice(new AudioDeviceModuleImpl(audio_layer));

    audioDevice->CheckPlatform();
    audioDevice->CreatePlatformSpecificObjects();
    audioDevice->AttachAudioBuffer();

    return audioDevice;
}
```

```
AudioDeviceModuleImpl::CreatePlatformSpecificObjects(){
    // WEBRTC_DUMMY_AUDIO_BUILD
    audio_device_.reset(new AudioDeviceDummy());
    // WEBRTC_DUMMY_FILE_DEVICES
    audio_device_.reset(FileAudioFactory::CreateFileAudioDevice());

    // WEBRTC_WINDOWS_CORE_AUDIO_BUILD
    audio_device_.reset(new AudioDeviceWindowsCore());

    // WEBRTC_ANDROID
    audio_manager_android_.reset(new AudioManager());
    if(audio_layer == kPlatformDefaultAudio){
        audio_layer = kAndroidOpenSLESAudio;
    } else if(isLowLatencySupported){
        audio_layer = kAndroidJavaInputAndroidOpenSLESOutputAudio;
    } else {
        audio_layer = kAndroidJavaAudio;
    }

    if(kAndroidJavaAudio){
        audio_device_.reset(new AudioDeviceTemplate<AudioRecordJni, AudioTrackJni>())
    } else if(kAndroidOpenSLESAudio){
        audio_device_.reset(new AudioDeviceTemplate<OpenSLESRecorder, OpenSLESPlayer>());
    } else if(kAndroidJavaInputAndOpenSLESOutputAudio){
        audio_device_.reset(new AudioDeviceTemplate<AudioRecordJni, OpenSLESPlayer>())
    }

    // WEBRTC_LINUX
    if(kLinuxPulseAudio || kPlatformDefaultAudio){
        audio_device_.reset(new AudioDeviceLinuxPulse())
    } else if(kLinuxAlsaAudio){
        audio_device_.reset(new AudioDeviceLinuxALSA())
    }
    // WEBRTC_IOS
    audio_device_.reset(new AudioDeviceIOS())
    // WEBRTC_MAC
    audio_device_.reset(new AudioDeviceMac())

}
```

我们以 Android 为例；使用 AudioDeviceTemplate 封装 音频输入（采集）、输出类型（渲染）； 
目前使用 AudioRecordJni 和 AudioTrackJni。
如果直接使用 NDK 的openSLES 开发的化，使用的是 OpenSLESRecorder 和 OpenSLESPlayer。

audio_manager.h
```
// JavaAudioManager
bool Init()
void Close()
bool IsCommunicationModeEnabled()
bool IsDeviceBlacklistedForOpenSLESUsage()


// private
JNICALL CacheAudioParameters()
void OnCacheAudioParameters()
```

audio_record_jni.h
```
//JavaAudioRecord
int InitRecording(int sample_reate, size_t channels);
bool StartRecording();
bool StopRecording();
bool EnableBuiltInAEC(bool enable);
bool EnableBuiltInNS(bool enable);

// public
int32_t Init();
int32_t Terminate();

int32_t InitRecording();
bool RecordingIsInitialized();

int32_t StartRecording();
int32_t StopRecording();
bool Recording();

void AttachAudioBuffer();
int32_t EnableBuiltInAEC(bool enable);
int32_t EnableBuiltInAGC(bool enable);
int32_t EnableBuiltInNS(bool enable);

// private
JNICALL CacheDirectBufferAddress()
void OnCacheDirectBufferAddress(jobject byte_buffer)

JNICALL DataIsRecorded();
void OnDataIsRecorded(int length);

```


audio_track_jni.h

```
// JavaAudioTrack
bool InitPlayout(int sample_rate, int channels);
bool StartPlayout();
bool StopPlayout();
bool SetStreamVolume(int volume);
int GetStreamMaxVolume();
int GetStreamVolume();

// public
Init()
Terminate()
InitPlayout()
PlayoutIsInitialized()
StartPlayout()
StopPlayout()
Playing()


SpeakerVolumeIsAvailable(bool available);
SetSpeakerVolume(volume);
SpeakerVolume(volume);
MaxSpeakerVolume(max_volume);
MinSpeakerVolume(min_volume);
AttachAudioBuffer(audioBuffer);

// private
JNICALL CacheDirectBufferAddress();
void OnCacheDirectBufferAddress(jobject byte_buffer);

JNICALL GetPlayoutData();
void OnGetPlayoutData(size_t length);
```



### AudioRecordJni

#### 音频采集初始化
AudioRecordJni 初始化时，在构造方法中初始化 JavaAudioRecord。
```
j_audio-record_.reset(
    new JavaAudioRecord()
)
```

然后在 webrtcvoiceengine 中 AddSendStream 后，SetSend() 配置媒体通道发送。

```
//media/engine/webrtcvoiceengine.cc
WebRtcVoiceMediaChannel::SetSend(bool send){
    ...
    if(send){
        engine()->ApplyOptions(options_);
        if(!engine()->adm()->RecordingIsInitialized() 
        && !engine()->adm()->Recording()){

            engine()->adm()->InitRecording();
        }
    }
    ...
}
```
这里面会初始化 AudioRecord。

InitRecording() 方法实现，在 Android 中实在 audio_record_jni.cc 的 JavaAudioRecord::InitRecording() ，最终通过 JNI 回调 Java 层的 InitRecording() 方法。

#### 音频采集
初始化完成后，就要开始采集音频数据。


/audio/audio_send_stream.cc
音频发送流里面 AudioSendStream::Start() 方法启动音频流发送；


```
AudioSendSstream::Start(){
    channel_proxy_->StartSend();
    audio_state()->AddSendingStream(this, encoder_sample_rate_hz_, encoder_num_channels_);
}
```

调用 /audio/audio_state.cc 的 AudioState::AddSendingStream() 方法；

```
AudioState::AddSendingStream(){
    auto* adm = config_.audio_device_module.get();
    ...
    amd->StartRecording();
    ...
}
```

#### 音频开关

另外，PeerConnection 提供了 音频采集开关。

```
//org.webrtc.PeerConnection.java
public void setAudioRecording(boolean recording){
    nativeSetAudioRecording();
}
```

对应的JNI方法
```
//JNI/pc/peerconnection.cc
void JNI_PeerConnection_SetAudioRecording(){
    ExtractNativePC(jni,j_pc)->SetAudioRecording(recording);
}
```

其实JNI方法也是调用 webrtc 的 peerconnection

```
//webrtc/pc/peerconnection.cc
PeerConnection::SetAudioRecording(bool recording){
    auto audio_state = 
        factory_->channel_manager()->media_engine()->GetAudioState();
    // AudioState
    audio_state->SetRecording(recording);
}
```

由上代码可知， 通过 WebRtcVoiceEngine 的 GetAudioState() 方法获取 audio_state。
然后通过 audio_state 设置音频采集开关。

在 AudioState::SetRecording() 方法调用具体设备模块开始或停止音频采集。

```
//webrtc/audio/audio_state.cc
AudioState::SetRecording(bool enabled){
    ...
    if(enabled){
        config_.audio_device_module->StartRecording();
    }else{
        config_.audio_device_module->StopRecording();
    }
}
```

#### 音频采集具体实现

这里我们只以Android为例。

如果使用 opensles ndk 采集音频，采集的具体实现在 opensles_recorder.cc 文件的 StartRecording() 方法。

```
// modules/audio_device/android/opensles_recorder.cc
int OpenSLESRecorder::StartRecording(){
    ...
}
```
这种方法的具体实现我们暂时不深入。


我们讨论 java 实现方案。

java 实现的jni类，audio_record_jni.cc
```
//modules/audio_device/android/audio_record_jni.cc
AudioRecordJni::StartRecording(){
    ...
    j_audio_record_->StartRecording()
    ...
}
```

j_audio_record_->StartRecording() 调用的就是 AudioRecordJni::JavaAudioRecord::StartRecording() 方法。

```
AudioRecordJni::JavaAudioRecord::StartRecording(){
    return audio_record_->CallBooleanMethod(start_recording_);
}
```

CallBooleanMethod 就是jni回调java 实现的封装，最终实现回调 WebRtcAudioRecord.java 中的 StartRecording() 方法。

```
//org.webrtc.voiceengine.WebRtcAudioRecord.java 
boolean startRecording(){
    audioRecord.startRecording();
    audioThread = new AudioRecordThread("AudioRecordJavaThread");
    audioThread.start();
}
```

#### 音频采集线程

音频采集线 AudioRecordThread；我们只跟踪 run() 方法。

```
@Override
public void run(){
    ...
    while(keepAlive){
        int bytesRead = audioRecord.read(byteBuffer, byteBuffer.capacity());


        // 通知 native 音频数据
        nativeDataIsRecorded(bytesRead, nativeAudioRecord);

        // 应用音频采集回调
        byte[] data = Arrays.copyOf(byteBuffer.array(), byteBuffer.capacity());
        audioSamplesReadyCallback.onWebRtcAudioRecordSamplesReady(
            new AudioSamples(audioRecord, data)
        );
    }
    ...
}

```
