title: Rxjava2操作符
date: 2018/04/12 20:20:50
categories: Android
comments: true
tags: [android,开源框架,rxjava2]
---
## Rxjava2 操作符
- ### Create
**create**操作符，主要用于产生一个 **Obserable** 被观察者对象，因为**Observable**主要用于发射事件，**Observer**主要用于消费时间，所以以后统一把被观察者 **Observable** 称为发射器（上游事件），观察者 **Observer** 称为接收器（下游事件）。

```java
Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(@NonNull ObservableEmitter<Integer> e) throws Exception {
                mRxOperatorsText.append("Observable emit 1" + "\n");
                Log.e(TAG, "Observable emit 1" + "\n");
                e.onNext(1);
                mRxOperatorsText.append("Observable emit 2" + "\n");
                Log.e(TAG, "Observable emit 2" + "\n");
                e.onNext(2);
                mRxOperatorsText.append("Observable emit 3" + "\n");
                Log.e(TAG, "Observable emit 3" + "\n");
                e.onNext(3);
                e.onComplete();
                mRxOperatorsText.append("Observable emit 4" + "\n");
                Log.e(TAG, "Observable emit 4" + "\n" );
                e.onNext(4);
            }
        }).subscribe(new Observer<Integer>() {
            private int i;
            private Disposable mDisposable;

            @Override
            public void onSubscribe(@NonNull Disposable d) {
                mRxOperatorsText.append("onSubscribe : " + d.isDisposed() + "\n");
                Log.e(TAG, "onSubscribe : " + d.isDisposed() + "\n" );
                mDisposable = d;
            }

            @Override
            public void onNext(@NonNull Integer integer) {
                mRxOperatorsText.append("onNext : value : " + integer + "\n");
                Log.e(TAG, "onNext : value : " + integer + "\n" );
                i++;
                if (i == 2) {
                    // 在RxJava 2.x 中，新增的Disposable可以做到切断的操作，让Observer观察者不再接收上游事件
                    mDisposable.dispose();
                    mRxOperatorsText.append("onNext : isDisposable : " + mDisposable.isDisposed() + "\n");
                    Log.e(TAG, "onNext : isDisposable : " + mDisposable.isDisposed() + "\n");
                }
            }

            @Override
            public void onError(@NonNull Throwable e) {
                mRxOperatorsText.append("onError : value : " + e.getMessage() + "\n");
                Log.e(TAG, "onError : value : " + e.getMessage() + "\n" );
            }

            @Override
            public void onComplete() {
                mRxOperatorsText.append("onComplete" + "\n");
                Log.e(TAG, "onComplete" + "\n" );
            }
        });
```
---
- ### Map
**Map** 基本算是 RxJava 中一个最简单的操作符了，熟悉 RxJava 1.x 的知道，它的作用是对发射时间发送的每一个事件应用一个函数，是的每一个事件都按照指定的函数去变化，而在 2.x 中它的作用几乎一致。**map** 基本作用就是将一个 **Observable** 通过某种函数关系，转换为另一种 **Observable**，下面例子中就是把我们的 Integer 数据变成了 String 类型。从Log日志显而易见。
 
```java 
Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(@NonNull ObservableEmitter<Integer> e) throws Exception {
                e.onNext(1);
                e.onNext(2);
                e.onNext(3);
            }
        }).map(new Function<Integer, String>() {
            @Override
            public String apply(@NonNull Integer integer) throws Exception {
                return "This is result " + integer;
            }
        }).subscribe(new Consumer<String>() {
            @Override
            public void accept(@NonNull String s) throws Exception {
                mRxOperatorsText.append("accept : " + s +"\n");
                Log.e(TAG, "accept : " + s +"\n" );
            }
        });

```
---
- ### Zip

zip 专用于合并事件，该合并不是连接（连接操作符后面会说），而是两两配对，也就意味着，最终配对出的 **Observable** 发射事件数目只和少的那个相同。

```java
Observable.zip(getStringObservable(), getIntegerObservable(), new BiFunction<String, Integer, String>() {
            @Override
            public String apply(@NonNull String s, @NonNull Integer integer) throws Exception {
                return s + integer;
            }
        }).subscribe(new Consumer<String>() {
            @Override
            public void accept(@NonNull String s) throws Exception {
                mRxOperatorsText.append("zip : accept : " + s + "\n");
                Log.e(TAG, "zip : accept : " + s + "\n");
            }
        });
        
/**
*注： getStringObservable 返回A B C ，getIntegerObservable返回的是1 2 3 4 5 
*/

```
输出结果：

![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/628B12999CCE43C8A9FD5994B01C24CF/2176)
**zip** 组合事件的过程就是分别从发射器 A 和发射器 B 各取出一个事件来组合，并且一个事件只能被使用一次，组合的顺序是严格按照事件发送的顺序来进行的，所以上面截图中，可以看到，1 永远是和 A 结合的，2 永远是和 B 结合的。

**最终接收器收到的事件数量是和发送器发送事件最少的那个发送器的发送事件数目相同**
上面的例子就可以看出 结合后的事件数量是3 

---
- #### Concat

因为**zip**连接事件有上述两个特点：

```
1. 分别从两个发射器取一个事件组合成新事件，且事件组合顺序与发射顺序严格相同 
2. 最终接受事件数量与原始发射器数量最小的那个相同
```

对于单一的把两个发射器连接成一个发射器，可以尝试**Contact**


```java
Observable.concat(Observable.just(1,2,3), Observable.just(4,5,6))
                .subscribe(new Consumer<Integer>() {
                    @Override
                    public void accept(@NonNull Integer integer) throws Exception {
                        mRxOperatorsText.append("concat : "+ integer + "\n");
                        Log.e(TAG, "concat : "+ integer + "\n" );
                    }
                });

```
**输出结果
123456**
---
- #### FlatMap

**FlatMap** ，它可以把一个发射器  **Observable** 通过某种方法转换为多个 **Observables**，然后再把这些分散的 **Observables**装进一个单一的发射器 **Observable**。但有个需要注意的是，**flatMap** ==并不能保证事件的顺序==，如果需要保证，需要用到我们下面要讲的 **ConcatMap**。

```java
Observable.create(new ObservableOnSubscribe<Integer>() {
           @Override
           public void subscribe(@NonNull ObservableEmitter<Integer> e) throws Exception {
               e.onNext(1);
               e.onNext(2);
               e.onNext(3);
           }
       }).flatMap(new Function<Integer, ObservableSource<String>>() {
           @Override
           public ObservableSource<String> apply(@NonNull Integer integer) throws Exception {
               List<String> list = new ArrayList<>();
               for (int i = 0; i < 3; i++) {
                   list.add("I am value " + integer);
               }
               int delayTime = (int) (1 + Math.random() * 10);
               return Observable.fromIterable(list).delay(delayTime, TimeUnit.MILLISECONDS);
               // 使用delay操作符，做一个小延时操作，而查看 Log 日志也表明，FlatMap是无序的。
           }
       }).subscribeOn(Schedulers.newThread())
               .observeOn(AndroidSchedulers.mainThread())
               .subscribe(new Consumer<String>() {
                   @Override
                   public void accept(@NonNull String s) throws Exception {
                       Log.e(TAG, "flatMap : accept : " + s + "\n");
                       mRxOperatorsText.append("flatMap : accept : " + s + "\n");
                   }
               });


```

![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/5C40758F7CD94BEAA7D939C4663F4FA0/2212)
 输出
 
```
2,3,3,3,2,2,1,1
```
---
- ### concatMap

上面其实就说了，**concatMap** 与 **FlatMap** 的唯一区别就是 **concatMap** 保证了顺序，所以，我们就直接把 **flatMap** 替换为 **concatMap** 验证。


```java
Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(@NonNull ObservableEmitter<Integer> e) throws Exception {
                e.onNext(1);
                e.onNext(2);
                e.onNext(3);
            }
        }).concatMap(new Function<Integer, ObservableSource<String>>() {
            @Override
            public ObservableSource<String> apply(@NonNull Integer integer) throws Exception {
                List<String> list = new ArrayList<>();
                for (int i = 0; i < 3; i++) {
                    list.add("I am value " + integer);
                }
                int delayTime = (int) (1 + Math.random() * 10);
                return Observable.fromIterable(list).delay(delayTime, TimeUnit.MILLISECONDS);
            }
        }).subscribeOn(Schedulers.newThread())
                .observeOn(AndroidSchedulers.mainThread())
                .subscribe(new Consumer<String>() {
                    @Override
                    public void accept(@NonNull String s) throws Exception {
                        Log.e(TAG, "flatMap : accept : " + s + "\n");
                        mRxOperatorsText.append("flatMap : accept : " + s + "\n");
                    }
                });

```

输出结果：

```
1 1 1 2 2 2 3 3 3
```
---
- ### distinct
作用是去重，输入
```
1 1 2 2 3 4 5
```

输出 
```
1 2 3 4 5
```

```java

Observable.just(1, 1, 1, 2, 2, 3, 4, 5)
                .distinct()
                .subscribe(new Consumer<Integer>() {
                    @Override
                    public void accept(@NonNull Integer integer) throws Exception {
                        mRxOperatorsText.append("distinct : " + integer + "\n");
                        Log.e(TAG, "distinct : " + integer + "\n");
                    }
                });

```
---
- ### Filter
**Filter** 过滤器，可以接受一个参数，让其过滤掉不符合我们条件的值


```java
Observable.just(1, 20, 65, -5, 7, 19)
                .filter(new Predicate<Integer>() {
                    @Override
                    public boolean test(@NonNull Integer integer) throws Exception {
                        return integer >= 10;
                    }
                }).subscribe(new Consumer<Integer>() {
            @Override
            public void accept(@NonNull Integer integer) throws Exception {
                mRxOperatorsText.append("filter : " + integer + "\n");
                Log.e(TAG, "filter : " + integer + "\n");
            }
        });

```
输出
大于10的事件

```
20 65 19
```

--- 
- ### buffer

**buffer** 操作符接受两个参数，buffer(count,skip)作用是将 **Observable** 中的数据按 **skip** (步长) 分成最大不超过 **count** 的 **buffer** ，然后生成一个  **Observable** 。也就是说 ==按照步长，将原始事件 分成一组一组  重新发射出去==


```java
Observable.just(1, 2, 3, 4, 5)
                .buffer(3, 2)
                .subscribe(new Consumer<List<Integer>>() {
                    @Override
                    public void accept(@NonNull List<Integer> integers) throws Exception {
                        mRxOperatorsText.append("buffer size : " + integers.size() + "\n");
                        Log.e(TAG, "buffer size : " + integers.size() + "\n");
                        mRxOperatorsText.append("buffer value : ");
                        Log.e(TAG, "buffer value : " );
                        for (Integer i : integers) {
                            mRxOperatorsText.append(i + "");
                            Log.e(TAG, i + "");
                        }
                        mRxOperatorsText.append("\n");
                        Log.e(TAG, "\n");
                    }
                });

```

输出结果

```
size 3
value 1 2 3 
size 3
value 3 4 5 
size 1 
value 5
```

---
- ### timer

**timer**，相当于一个定时任务。在 1.x 中它还可以执行间隔逻辑，但在 2.x 中此功能被交给了 **interval**。但需要注意的是，**timer** 和 **interval** 均==默认在新线程==。
==执行timer方法，将使得接受延时==


```java
mRxOperatorsText.append("timer start : " + TimeUtil.getNowStrTime() + "\n");
        Log.e(TAG, "timer start : " + TimeUtil.getNowStrTime() + "\n");
        Observable.timer(2, TimeUnit.SECONDS)
                .subscribeOn(Schedulers.io())
                .observeOn(AndroidSchedulers.mainThread()) // timer 默认在新线程，所以需要切换回主线程
                .subscribe(new Consumer<Long>() {
                    @Override
                    public void accept(@NonNull Long aLong) throws Exception {
                        mRxOperatorsText.append("timer :" + aLong + " at " + TimeUtil.getNowStrTime() + "\n");
                        Log.e(TAG, "timer :" + aLong + " at " + TimeUtil.getNowStrTime() + "\n");
                    }
                });
```

当我们两次点击按钮触发这个事件的时候，接收被延迟了 2 秒。
---
- ### interval

如同我们上面可说，**interval** 操作符用于间隔时间执行某个操作，其接受三个参数，分别是**第一次发送延迟**，**间隔时间**，**时间单位**。


```java
mRxOperatorsText.append("interval start : " + TimeUtil.getNowStrTime() + "\n");
       Log.e(TAG, "interval start : " + TimeUtil.getNowStrTime() + "\n");
       Observable.interval(3,2, TimeUnit.SECONDS)
               .subscribeOn(Schedulers.io())
               .observeOn(AndroidSchedulers.mainThread()) // 由于interval默认在新线程，所以我们应该切回主线程
               .subscribe(new Consumer<Long>() {
                   @Override
                   public void accept(@NonNull Long aLong) throws Exception {
                       mRxOperatorsText.append("interval :" + aLong + " at " + TimeUtil.getNowStrTime() + "\n");
                       Log.e(TAG, "interval :" + aLong + " at " + TimeUtil.getNowStrTime() + "\n");
                   }
               });
```

执行结果是第一次延迟了 3 秒后接收到，后面每次间隔了 2 秒。
然而，由于我们这个是间隔执行，所以当我们的Activity 都销毁的时候，==实际上这个操作还依然在进行==，查看源码发现，我们
```
subscribe(Cousumer<? super T> onNext)
```
返回的是**Disposable**，**Disposable** 可以用来解除绑定。




```java
@Override
   protected void doSomething() {
       mRxOperatorsText.append("interval start : " + TimeUtil.getNowStrTime() + "\n");
       Log.e(TAG, "interval start : " + TimeUtil.getNowStrTime() + "\n");
       mDisposable = Observable.interval(3, 2, TimeUnit.SECONDS)
               .subscribeOn(Schedulers.io())
               .observeOn(AndroidSchedulers.mainThread()) // 由于interval默认在新线程，所以我们应该切回主线程
               .subscribe(new Consumer<Long>() {
                   @Override
                   public void accept(@NonNull Long aLong) throws Exception {
                       mRxOperatorsText.append("interval :" + aLong + " at " + TimeUtil.getNowStrTime() + "\n");
                       Log.e(TAG, "interval :" + aLong + " at " + TimeUtil.getNowStrTime() + "\n");
                   }
               });
   }

   @Override
   protected void onDestroy() {
       super.onDestroy();
       if (mDisposable != null && !mDisposable.isDisposed()) {
           mDisposable.dispose();
       }
   }
```

---
- ### doOnNext

**doOnNext** 它的作用是让订阅者在接收到数据之前做一些其他操作。假如我们在获取到数据之前想先保存一下它，无疑我们可以这样实现。


```java
Observable.just(1, 2, 3, 4)
                .doOnNext(new Consumer<Integer>() {
                    @Override
                    public void accept(@NonNull Integer integer) throws Exception {
                        mRxOperatorsText.append("doOnNext 保存 " + integer + "成功" + "\n");
                        Log.e(TAG, "doOnNext 保存 " + integer + "成功" + "\n");
                    }
                }).subscribe(new Consumer<Integer>() {
            @Override
            public void accept(@NonNull Integer integer) throws Exception {
                mRxOperatorsText.append("doOnNext :" + integer + "\n");
                Log.e(TAG, "doOnNext :" + integer + "\n");
            }
        });
```
---
- ### skip

**skip** ，接受一个 **long** 型参数 **count** ，代表跳过 **count** 个数目开始接收。


```java
Observable.just(1,2,3,4,5)
                .skip(2)
                .subscribe(new Consumer<Integer>() {
                    @Override
                    public void accept(@NonNull Integer integer) throws Exception {
                        mRxOperatorsText.append("skip : "+integer + "\n");
                        Log.e(TAG, "skip : "+integer + "\n");
                    }
                });
```

输出：

```
3 4 5
```
---
- ###  take

**take**，接受一个 **long** 型参数 **count** ，代表至多接收 **count** 个数据。


```java
Flowable.fromArray(1,2,3,4,5)
                .take(2)
                .subscribe(new Consumer<Integer>() {
                    @Override
                    public void accept(@NonNull Integer integer) throws Exception {
                        mRxOperatorsText.append("take : "+integer + "\n");
                        Log.e(TAG, "accept: take : "+integer + "\n" );
                    }
                });
```

输出：

```
1 2
```

---
- ### just

**just**一个简单的发射器依次调用 onNext() 方法。


```java
Observable.just("1", "2", "3")
                .subscribeOn(Schedulers.io())
                .observeOn(AndroidSchedulers.mainThread())
                .subscribe(new Consumer<String>() {
                    @Override
                    public void accept(@NonNull String s) throws Exception {
                        mRxOperatorsText.append("accept : onNext : " + s + "\n");
                        Log.e(TAG,"accept : onNext : " + s + "\n" );
                    }
                });
```

输出：


```
1 2 3
```
---
- ### Single

顾名思义，Single 只会接收一个参数，也就是只发射一次事件，他的而 SingleObserver 只会调用 **onError()** 或者 **onSuccess()**。


```java
Single.just(new Random().nextInt())
                .subscribe(new SingleObserver<Integer>() {
                    @Override
                    public void onSubscribe(@NonNull Disposable d) {

                    }

                    @Override
                    public void onSuccess(@NonNull Integer integer) {
                        mRxOperatorsText.append("single : onSuccess : "+integer+"\n");
                        Log.e(TAG, "single : onSuccess : "+integer+"\n" );
                    }

                    @Override
                    public void onError(@NonNull Throwable e) {
                        mRxOperatorsText.append("single : onError : "+e.getMessage()+"\n");
                        Log.e(TAG, "single : onError : "+e.getMessage()+"\n");
                    }
                });
```

输出：

```
onSuccess
```
---- 
- ### distinct

去重操作符，简单的作用就是去重。

```java
Observable.just(1, 1, 1, 2, 2, 3, 4, 5)
                .distinct()
                .subscribe(new Consumer<Integer>() {
                    @Override
                    public void accept(@NonNull Integer integer) throws Exception {
                        mRxOperatorsText.append("distinct : " + integer + "\n");
                        Log.e(TAG, "distinct : " + integer + "\n");
                    }
                });
```

输出：

```
1 2 3 4 5
```
发射器发送的事件，在接收的时候被去重了。

---
- ### debounce

去除发送频率过快的项，可以用来过滤点击过快的点击事件


```java
Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(@NonNull ObservableEmitter<Integer> emitter) throws Exception {
                // send events with simulated time wait
                emitter.onNext(1); // skip
                Thread.sleep(400);
                emitter.onNext(2); // deliver
                Thread.sleep(505);
                emitter.onNext(3); // skip
                Thread.sleep(100);
                emitter.onNext(4); // deliver
                Thread.sleep(605);
                emitter.onNext(5); // deliver
                Thread.sleep(510);
                emitter.onComplete();
            }
        }).debounce(500, TimeUnit.MILLISECONDS)
                .subscribeOn(Schedulers.io())
                .observeOn(AndroidSchedulers.mainThread())
                .subscribe(new Consumer<Integer>() {
                    @Override
                    public void accept(@NonNull Integer integer) throws Exception {
                        mRxOperatorsText.append("debounce :" + integer + "\n");
                        Log.e(TAG,"debounce :" + integer + "\n");
                    }
                });
```

输出：


```
2 4 5
```


代码很清晰，去除发送间隔时间小于 500 毫秒的发射事件，所以 1 和 3 被去掉了。

---
- ### defer

==直到有订阅，才会创建Observable==
具有延时的效果。

代码对比如下：


```java
a = 10;
Observable<String> o1 = Observable.just("just result: " + a);
a = 12;
o1.subscribe(new Action1<String>() {

    @Override
    public void call(String t) {
        System.out.println(t);
    }
});
```


输出： 

```
just result: 10
```


可见： 
在使用**just**的时候，便创建了**Observable**对象，随后改变a的值，并不会改变**Observable**对象中的值。

**使用defer**


```java
a = 12;
Observable<String> o2 = 
    Observable.defer(new Func0<Observable<String>>() {

    @Override
    public Observable<String> call() {
        return Observable.just("defer result: " + a);
    }
});
a = 20;

o2.subscribe(new Action1<String>() {

    @Override
    public void call(String t) {
        System.out.println(t);
    }
    });
```

输出： 

```
defer result: 20
```


可见： 
**在a=12时，虽然定义了一个Observable，但是并没有创建这个示例，当a=20时，这时候订阅这个Observable，则开始创建，所以对象中的a为20.**

---
- ### last

**last** 操作符仅取出可观察到的最后一个值，或者是满足某些条件的最后一项。


```java
Observable.just(1, 2, 3)
                .last()
                .subscribe(new Consumer<Integer>() {
                    @Override
                    public void accept(@NonNull Integer integer) throws Exception {
                        mRxOperatorsText.append("last : " + integer + "\n");
                        Log.e(TAG, "last : " + integer + "\n");
                    }
                });
```

输出：
```
3
```
 
---
- ### merge

**merge** 顾名思义 在 Rx 操作符中，**merge** 的作用是把多个 **Observable** 结合起来，接受可变参数，也支持迭代器集合。注意它和 **concat** 的区别在于，==不用等到 发射器 A 发送完所有的事件再进行发射器 B 的发送==。


```java
Observable.merge(Observable.just(1, 2), Observable.just(3, 4, 5))
                .subscribe(new Consumer<Integer>() {
                    @Override
                    public void accept(@NonNull Integer integer) throws Exception {
                        mRxOperatorsText.append("merge :" + integer + "\n");
                        Log.e(TAG, "accept: merge :" + integer + "\n" );
                    }
                });
```

输出：

```
1 2 3 4 5
```



---
- ### reduce

**reduce** 操作符每次用一个方法处理一个值，可以有一个 **seed** 作为初始值。


```java
Observable.just(1, 2, 3)
               .reduce(new BiFunction<Integer, Integer, Integer>() {
                   @Override
                   public Integer apply(@NonNull Integer integer, @NonNull Integer integer2) throws Exception {
                       return integer + integer2;
                   }
               }).subscribe(new Consumer<Integer>() {
           @Override
           public void accept(@NonNull Integer integer) throws Exception {
               mRxOperatorsText.append("reduce : " + integer + "\n");
               Log.e(TAG, "accept: reduce : " + integer + "\n");
           }
       });
```

输出：
```
6
```


可以看到，代码中，我们中间采用 reduce ，支持一个 function 为两数值相加，所以应该最后的值是：1 + 2 = 3 + 3 = 6 ，

---
- ### scan

**scan** 操作符作用和上面的 **reduce** 一致，唯一区别是 **reduce** 是个只追求结果的坏人，而  **scan** 会始终如一地把每一个步骤都输出。


```java
Observable.just(1, 2, 3)
                .scan(new BiFunction<Integer, Integer, Integer>() {
                    @Override
                    public Integer apply(@NonNull Integer integer, @NonNull Integer integer2) throws Exception {
                        return integer + integer2;
                    }
                }).subscribe(new Consumer<Integer>() {
            @Override
            public void accept(@NonNull Integer integer) throws Exception {
                mRxOperatorsText.append("scan " + integer + "\n");
                Log.e(TAG, "accept: scan " + integer + "\n");
            }
        });
```

输出：

```
1 3 6
```

---
- ### window

按照实际划分窗口，将数据发送给不同的 **Observable**


```java
mRxOperatorsText.append("window\n");
       Log.e(TAG, "window\n");
       Observable.interval(1, TimeUnit.SECONDS) // 间隔一秒发一次
               .take(15) // 最多接收15个
               .window(3, TimeUnit.SECONDS)
               .subscribeOn(Schedulers.io())
               .observeOn(AndroidSchedulers.mainThread())
               .subscribe(new Consumer<Observable<Long>>() {
                   @Override
                   public void accept(@NonNull Observable<Long> longObservable) throws Exception {
                       mRxOperatorsText.append("Sub Divide begin...\n");
                       Log.e(TAG, "Sub Divide begin...\n");
                       longObservable.subscribeOn(Schedulers.io())
                               .observeOn(AndroidSchedulers.mainThread())
                               .subscribe(new Consumer<Long>() {
                                   @Override
                                   public void accept(@NonNull Long aLong) throws Exception {
                                       mRxOperatorsText.append("Next:" + aLong + "\n");
                                       Log.e(TAG, "Next:" + aLong + "\n");
                                   }
                               });
                   }
               });
```

输出：

![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/4D0E7ABEF33943A9AC0BBC68A8E1B608/2320)