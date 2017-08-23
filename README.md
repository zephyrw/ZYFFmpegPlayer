# ZYFFmpegPlayer
对视频的解码，我们需要使用`libavformat`和`libavcodec`这两个库。`libavformat`库主要负责输入输出、封装和解封装，`libavcodec `库主要负责编解码，所以要使用相应功能之前要先导入头文件`avformat.h`和`avcodec.h`。

## 初始化

首先我们需要对FFmepg各个库进行初始化，这个初始化工作在囊个app生命周期只执行一次即可，所以你的代码应该是这样的：

```
static dispatch_once_t onceToken;
dispatch_once(&onceToken, ^{
av_register_all();
avformat_network_init();
avcodec_register_all();
});
```

其中`av_register_all()`会初始化所有的`muxer`、`demuxer`和代码。`muxer`代码音视频复用器，它会把编码好的视频数据和音频数据合并到一个封装格式数据(比如mp4)中去，同理`demuxer`是解封装。

`avformat_network_init()`会初始化所有的网络模块。

`avcodec_register_all()`会注册所有类型的解码器，如果只用特定格式的解码器，可以单独注册。

## 文件操作

首先要创建`AVFormatContext`，用以管理文件的输入输出：

``` objc
_format_context = avformat_alloc_context();
```

然后是打开输入，这个输入可以是本地视频文件地址，也可以是视频流地址。如果文件打开失败，要调用`avformat_free_context()`及时释放掉`AVFormatContext`。如果打开成功，后面不再需要输入文件的操作，要调用`avformat_close_input(&_format_context)`来关闭输入。

``` objc
result = avformat_open_input(&_format_context, self.filePath.UTF8String, NULL, NULL);
if (result < 0) {
NSLog(@"Failed to open input");
if (_format_context) {
avformat_free_context(_format_context);
}
return;
}
```

接着需要将视音频流的信息读取到`AVFormatContext`，`AVFormatContext`中有信息，才能进行查找视频流、音频流及相应的解码器的操作：

``` objc
result = avformat_find_stream_info(_format_context, NULL);
if (result) {
NSLog(@"Failed to find stream info!");
if (_format_context) {
avformat_close_input(&_format_context);
}
return;
}
```

如果上面的方法成功了，就可以直接打印整个视频文件的信息了：

```
av_dump_format(_format_context, 0, _filePath.UTF8String, 0);
```
至此，对于视频文件基本信息的读取操作已经完成了。

## 初始化音/视频解码器

接下来需要初始化视音频的`AVCodec`(解码器)和`AVCodecContext`(解码器上下文)。注意，这里音频的`AVCodec`和`AVCodecContext`和视频的是分开的，但是它们的流程是一模一样的，所以这部分可以单独抽一个方法出来。

首先根据类型找到音频或视频的序号，并在同时匹配到最适合的解码器。注：在之前的版本中会使用for循环来手动查找视频流或者音频流，并且要在后面单独进行解码器的查找操作，比较麻烦，现在一个方法就搞定，方便得多。

```
AVCodec *codec;
int streamIndex = av_find_best_stream(_format_context, AVMEDIA_TYPE_VIDEO, -1, -1, &codec, 0); // 以查找视频流为例，
```
这样通过序号就能找到视频流或者音频流了：

```
AVStream *stream = _format_context->streams[streamIndex];
```

接下来通过匹配到的解码器创建`AVCodecContext`(解码器上下文)并把视/音频流里的参数传到视/音频解码器中：

```
AVCodecContext *codecContext = avcodec_alloc_context3(codec);
avcodec_parameters_to_context(codecContext, stream->codecpar);
av_codec_set_pkt_timebase(codecContext, stream->time_base);
```

这里的`codecpar`表示包含解码器的各种参数的结构体。
而`time_base`则是一个代表分数的结构体，num 为分数，den为分母，它表示时间的刻度。时间量乘以刻度就可以得到时间。
如果是(1, 25)，那么时间刻度就是1/25。这里要注意的是`AVStream`的`time_base`与`AVCodecContext`的`time_base`是不同的，上面的方法就涉及到`time_base`的转换，所以要换算得到时间就要选取相应的`time_base`。

如果要得到`double`形式的`time_base`，可以调用`av_q2d()`函数，这个操作在这种分数结构体中会经常用到：

```
timeBase = av_q2d(codecContext->time_base);
```

接下来就可以打开解码器上下文准备进行解码操作了：

```
int result = avcodec_open2(codecContext, codec, NULL);
if (result) {
NSLog(@"Failed to open avcodec!");
avcodec_free_context(&codecContext);
return;
}
```

## 解码

在进行解码之前，要先了解两个基本的结构体：`AVPacket`和`AVFrame`。

### AVPacket

`AVPacket`表示编码（即压缩）后的数据，这种格式的音视频数据可以直接通过`muxer`封装成类似MKV的封装格式。如果`AVPacket`存的是视频数据，通常一个`AVPacket`只存放一桢数据（对应一个`AVFrame`），如果`AVPacket`存的是音频数据，那么一个`AVPacekt`里就可能存放多个桢的数据（对应多个`AVFrame`）。

### AVFrame

`AVFrame`表示解码后的音/视频数据，它在使用之前必须进行初始化`av_frame_alloc()`。通常它只需要初始化一次就可以了，在解码过程中它可以作为一个容器被反复利用。

### 解码流程

在了解上面两个基本概念后，现在可以开始真正的解码了。

首先调用`av_read_frame()`将音/视频一小段一小段读取出来（视频是每次读取一桢，音频每次读取多桢），封装到`AVPacket`中，然后通过音/视频流的编号确定是音频数据还是视频数据并进行分别的解码操作。这里音/视频`AVPacket`的解码分别抽出了单独的方法。

```
- (void)readPacket {

AVPacket packet;
while (YES) {
int result = av_read_frame(_format_context, &packet);
if (result < 0) {
NSLog(@"Finish to read frame!");
break;
}
if (self.videoEnable && packet.stream_index == _videoStreamIndex) {
if (![self decodeVideoPacket:packet]) {
NSLog(@"Failed to decode audio packet");
continue;
}
}else if (self.audioEnable && packet.stream_index == audioStreamIndex) {
if (![self decodeAudioPacket:packet]) {
NSLog(@"Failed to decode audio packet");
continue;
}
}
}
}
```
解码音/视频需要使用一对函数`avcodec_send_packet()`和`avcodec_receive_frame()`，第一个函数发送未解码的包，第二个函数接收已解码的`AVFrame`。如果所有的`AVFrame`都接收完成则表示文件全部解码完成。相应的，编码也是一对函数`avcodec_send_frame()`和`avcodec_receive_packet()`。

* `avcodec_send_packet()`   发送未解码数据
* `avcodec_receive_frame()` 接收解码后的数据
* `avcodec_send_frame()`    发送未编码的数据
* `avcodec_receive_packet()` 接收编码后的数据

在这4个函数中的返回值中，都会有两个错误`AVERROR(EAGAIN)`和`AVERROR_EOF`。

如果是发送函数报`AVERROR(EAGAIN)`的错，表示已发送的`AVPacket`还没有被接收，不允许发送新的`AVPacket`。如果是接收函数报这个错，表示没有新的`AVPacket`可以接收，需要先发送`AVPacket`才能执行这个函数。

而如果报`AVERROR_EOF`的错，在以上4个函数中都表示编解码器处于`flushed`状态，无法进行发送和接收操作。

解码视频时每次发送的`AVPacket`通常是一桢视频，所以发送一次接收一次：

```
- (BOOL)decodeVideoPacket:(AVPacket)packet
int result = avcodec_send_packet(_codec_context, &packet);
if (result < 0 && result != AVERROR(EAGAIN) && result != AVERROR_EOF) {
NSLog(@"Failed to send packet!");
return NO;
}
result = avcodec_receive_frame(_codec_context, _temp_frame);
if (result < 0 && result != AVERROR(EAGAIN) && result != AVERROR_EOF) {
NSLog(@"Failed to receive frame: %d", result);
return NO;
}

// 对_temp_frame进行操作

av_packet_unref(&packet);
}
```

解码音频时每次发送的`AVPacket`通常会转换成多个`AVFrame`，所以在接收的时候需要使用`while`循环保证所有的`AVFrame`都被接收到：

```
- (BOOL)decodeAudioPacket:(AVPacket)packet
int result = avcodec_send_packet(_codec_context, &packet);
if (result < 0 && result != AVERROR(EAGAIN) && result != AVERROR_EOF) {
NSLog(@"Failed to send packet!");
return NO;
}
while (result >= 0) {
result = avcodec_receive_frame(_codec_context, _temp_frame);
if (result < 0) {
if (result != AVERROR(EAGAIN) && result != AVERROR_EOF) {
NSLog(@"Failed to receive frame: %d", result);
return NO;
}
break;
}
// 对_temp_frame进行操作
}
av_packet_unref(&packet);
}
```

至此，音/视频的编解码就全部完成了，后续可以利用解码后的`AVFrame`进行音/视频的播放。

## 总结

音/视频编解码中最重要的是两个上下文结构体：`AVFormatContext`和`AVCodecContext`。`AVFormatContext`主要负责对原始音/视频文件或音/视频流进行操作，获取原始音/视频数据的信息。而`AVCodecContext`主要是用于存储编解码需要的信息，提供相应的解码器进行解码。加深对这两个上下文的理解，音/视频的编解码就会更得心应手。
