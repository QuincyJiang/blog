title: 添加SE安全策略
date: 2017/3/15 19:10:10
categories: AOSP
comments: true
tags: [编译,SEAndroid]
---
## 一、 问题复现

```
1.service ro_isn /system/bin/isn.sh 
2.class late_start
3.user root
4.oneshot
```

kernel log会打印以下log：

```
Warning!  Service ro_isn needs a SELinux domain defined; please fix!
```

这是因为**Service ro_isn**没有在**SELinux**的监控之下，这种情况会提示你定义一个SELinux。
在这种情况下，你可以：
1.无视该条log，Service功能不受影响。各种权限不受限制。但是这样做会有风险。
2.为**Service ro_isn**定义一个**SELinux** **domain**，仅添加需要的权限，未允许的权限操作会被拒绝。具体方法请参照下节。

## 二、解决方法
### 1.
```
devices/qcom/sepolicy/common/
```
目录下新增**ro_isn.te**文件，内容如下：

```
type ro_isn, domain; 
type ro_isn_exec, exec_type, file_type;
```

## 2.
在
```
devices/qcom/sepolicy/Android.mk
```


中添加**ro_isn.te**文件，内容如下：

```
BOARD_SEPOLICY_UNION := \
... \
        hostapd.te \
        ro_isn.te
```

## 3.
在
```
devices/qcom/sepolicy/common/file_contexts
```
中增加如下内容：
###################################

```
# System files
#
...
/system/vendor/bin/slim_ap_daemon
u:object_r:location_exec:s0
/system/bin/isn.sh
u:object_r:ro_isn_exec:s0
```


## 4.
在**init.rc**中**service ro_isn**下添加
```
secure context by seclabel 
service ro_isn /system/bin/isn.sh 

 
class late_start 
user root 
oneshot 
seclabel u:r:ro_isn:s0
```

 
## 5.
编译并烧录bootimage
## 6.
如果编译不成功，失败原因如下：

```
Error while expanding policy
libsepol.check_assertion_helper: neverallow on line 233 of external/sepolicy/domain.te (or line 5194 of policy.conf) violated by allow ro_isn system_file:file { entrypoint };
make: *** [out/target/product/msm8226/obj/ETC/sepolicy_intermediates/sepolicy] 错误 1
```

这是因为系统在**domain.te**中定义了全局的**neverallow策略**，与**ro_isn.te**中**allow**的策略有冲突：

```
allow ro_isn system_file:file { entrypoint };
neverallow domain { file_type -exec_type }:file entrypoint;
```

 
请确定自己的service有必要需要这个权限。如无必要，请在自己的code中删除掉相关操作；如必要，可以在
```
external/sepolicy/domain.te
```
中冲突的**neverallow**
语句中添加自己为例外：

```
neverallow {
    domain
    -ro_isn
} { file_type -exec_type }:file entrypoint;
```


## 7.
在**service ro_isn**运行时，搜索关于“**ro_isn**”的
```
avc: denied log
```


```
<6>[ 13.547188](CPU:0-pid:320:logd.auditd) type=1400 audit(17468992.410:7): avc: denied { entrypoint } for pid=272 comm="init" path="/system/bin/isn.sh 

" dev="mmcblk0p38" ino=631 scontext=u:r:ro_isn:s0 tcontext=u:object_r:system_file:s0 tclass=file
```

## 8.
按照如下规则在**ro_isn.te**添加权限
**SELinux**规则语句一般如下：

```
allow  A  B:C  D;
```

可以从log中分别获取ABCD四个参数。
比如这行
```
warning log：
avc: denied { entrypoint } for pid=272 comm="init" path="/system/bin/isn.sh 

" dev="mmcblk0p38" ino=631 scontext=u:r:ro_isn:s0 tcontext=u:object_r:system_file:s0 tclass=file

avc:  denied  { transition } for  pid=320 comm="init" path="/system/xbin/fcgiserver.sh 

" dev="mmcblk0p21" ino=7873 scontext=u:r:init:s0 tcontext=u:r:fcgiserver:s0 tclass=process permissive=1
```

那么我们就得出最后的规则是：

```
allow qcomsysd  block_device:dir { search };
```



```
allow ro_isn system_file:file { entrypoint };
```

重复步骤**5-8**,直到没有关于**ro_isn**的**avc: denied log**
