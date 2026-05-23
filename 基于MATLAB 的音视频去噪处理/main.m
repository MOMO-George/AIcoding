%% ===================== 主程序：视频音频分离处理与重组 =====================
warning('off', 'all');  % 关闭警告

%% ===================== 1. 配置参数 =====================
disp('【步骤1/10】初始化配置参数...');
% 视频处理参数
originalVideoFile = 'jiaoda.mp4';     % 原始视频文件
noisyVideoOnlyFile = 'noisy_only4.mp4';    % 仅噪声视频（无音频）
restoredVideoOnlyFile = 'restored_only4.mp4'; % 仅还原视频（无音频）
noisyVideoWithAudioFile = 'noisy4.mp4'; % 带噪声音频的视频
restoredVideoWithAudioFile = 'restored4.mp4'; % 带去噪音频的视频

% 音频文件路径
originalAudioFile = 'origin4.wav';
noisyAudioFile = 'noisy4.wav';
restoredAudioFile = 'restored4.wav';

% =============== 优化的视频处理参数 ===============
% 噪声参数优化：让噪声更明显
noiseDensity = 0.04;                % 增加椒盐噪声密度（0.08比原来的0.03更明显）
noiseIntensity = 0.05;               % 噪声强度参数（0-1）
noiseType = 'mixed';                % 使用混合噪声类型：椒盐+高斯

% 去噪参数优化：让去噪效果更好
filterMethods = {'median', 'bilateral', 'adaptive'}; % 使用多种滤波方法
medianFilterWindow = [5 5];         % 增大中值滤波窗口
bilateralSigmaSpatial = 2;          % 双边滤波空间域标准差
bilateralSigmaRange = 0.1;          % 双边滤波颜色域标准差
adaptiveFilterSize = [5 5];         % 自适应滤波窗口大小
adaptiveNoiseVariance = 0.01;       % 自适应滤波器噪声方差

% 后处理参数
edgeEnhancement = true;             % 启用边缘增强
sharpeningFactor = 0.8;             % 锐化因子

% 视频质量控制
videoQuality = 100;                 % 输出视频质量

% =============== 音频参数（保持不变） ===============
snr_dB = 10;                        % 信噪比（越小噪声越大）
audioFilterPass = 1300;             % 通带截止频率 (Hz)
audioFilterStop = 1200;             % 阻带截止频率 (Hz)
audioSubtractValue = 200;           % 频谱减法阈值

%% ===================== 2. 读取视频并提取音频 =====================
disp('【步骤2/10】读取视频并提取音频...');
% 读取视频信息
vidReader = VideoReader(originalVideoFile);
frameRate = vidReader.FrameRate;
totalFrames = floor(vidReader.Duration * frameRate);
videoHeight = vidReader.Height;
videoWidth = vidReader.Width;

% 打印视频信息
fprintf('视频信息：\n');
fprintf('  帧率：%.2f fps\n', frameRate);
fprintf('  总帧数：%d\n', totalFrames);
fprintf('  分辨率：%d x %d\n', videoWidth, videoHeight);
fprintf('  时长：%.2f 秒\n', vidReader.Duration);

% 提取音频
try
    % 读取音频
    [audioData, audioFs] = audioread(originalVideoFile);
    
    % 如果是立体声，转换为单声道（取平均值）
    if size(audioData, 2) > 1
        audioData = mean(audioData, 2);
    end
    
    % 归一化
    audioData = audioData / max(abs(audioData(:)));
    
    % 保存原始音频
    audiowrite(originalAudioFile, audioData, audioFs);
    fprintf('音频信息：\n');
    fprintf('  采样率：%d Hz\n', audioFs);
    fprintf('  采样点数：%d\n', length(audioData));
    fprintf('  音频时长：%.2f 秒\n', length(audioData)/audioFs);
    
catch ME
    warning('无法从视频中提取音频，使用静默音频');
    % 创建静默音频
    audioDuration = vidReader.Duration;
    audioFs = 44100; % 默认采样率
    audioData = zeros(floor(audioDuration * audioFs), 1);
    audiowrite(originalAudioFile, audioData, audioFs);
end

%% ===================== 3. 视频处理：添加混合噪声（让噪声更明显） =====================
disp('【步骤3/10】生成带混合噪声的视频（噪声更明显）...');
vidReader = VideoReader(originalVideoFile); % 重新打开视频读取器

% 创建噪声视频写入器（无音频）
vidWriter_noisy = VideoWriter(noisyVideoOnlyFile, 'MPEG-4');
vidWriter_noisy.FrameRate = frameRate;
vidWriter_noisy.Quality = videoQuality;
open(vidWriter_noisy);

% 创建视频信息存储
videoInfo.originalPSNR = zeros(totalFrames, 1);
videoInfo.noisyPSNR = zeros(totalFrames, 1);
videoInfo.ssimValues = zeros(totalFrames, 1);

% 进度条
h_wait1 = waitbar(0, '生成噪声视频（增强噪声）', 'Name', '视频处理中');
frameCount = 0;

% 逐帧处理
while hasFrame(vidReader)
    frameCount = frameCount + 1;
    waitbar(frameCount/totalFrames, h_wait1, sprintf('处理第 %d/%d 帧', frameCount, totalFrames));
    
    % 读取原始帧
    originalFrame = readFrame(vidReader);
    if isa(originalFrame, 'uint8')
        originalFrame_double = im2double(originalFrame);
    else
        originalFrame_double = originalFrame;
    end
    
    % =============== 增强的噪声添加 ===============
    % 方法1：椒盐噪声
    noisyFrame = imnoise(originalFrame_double, 'salt & pepper', noiseDensity);
    
    % 方法2：添加高斯噪声（让噪声更丰富）
    gaussianNoise = noiseIntensity * 0.1 * randn(size(noisyFrame));
    noisyFrame = noisyFrame + gaussianNoise;
    
    % 方法3：添加脉冲噪声（随机像素点）
    impulseMask = rand(size(noisyFrame)) < 0.02;
    noisyFrame(impulseMask) = rand(sum(impulseMask(:)), 1);
    
    % 方法4：块状噪声（模拟视频压缩噪声）
    if mod(frameCount, 5) == 0  % 每5帧添加块状噪声
        blockSize = 16;
        for i = 1:blockSize:size(noisyFrame,1)-blockSize
            for j = 1:blockSize:size(noisyFrame,2)-blockSize
                if rand() < 0.1  % 10%的块添加噪声
                    blockNoise = 0.2 * randn(blockSize, blockSize, size(noisyFrame,3));
                    noisyFrame(i:i+blockSize-1, j:j+blockSize-1, :) = ...
                        noisyFrame(i:i+blockSize-1, j:j+blockSize-1, :) + blockNoise;
                end
            end
        end
    end
    
    % 限制像素值范围
    noisyFrame = min(max(noisyFrame, 0), 1);
    
    % 计算PSNR和SSIM
    if frameCount <= length(videoInfo.originalPSNR)
        videoInfo.originalPSNR(frameCount) = psnr(originalFrame_double, originalFrame_double);
        videoInfo.noisyPSNR(frameCount) = psnr(noisyFrame, originalFrame_double);
        videoInfo.ssimValues(frameCount) = ssim(noisyFrame, originalFrame_double);
    end
    
    % 写入噪声帧
    writeVideo(vidWriter_noisy, noisyFrame);
end

close(h_wait1);
close(vidWriter_noisy);

%% ===================== 4. 视频处理：多方法联合降噪（让去噪效果更好） =====================
disp('【步骤4/10】对噪声视频进行多方法联合降噪...');
% 读取噪声视频
vidReader_noisy = VideoReader(noisyVideoOnlyFile);
% 重新读取原始视频用于对比
vidReader_original = VideoReader(originalVideoFile);

% 创建还原视频写入器
vidWriter_restored = VideoWriter(restoredVideoOnlyFile, 'MPEG-4');
vidWriter_restored.FrameRate = frameRate;
vidWriter_restored.Quality = videoQuality;
open(vidWriter_restored);

% 存储评估指标
videoInfo.restoredPSNR = zeros(totalFrames, 1);
videoInfo.restoredSSIM = zeros(totalFrames, 1);
videoInfo.methodsUsed = cell(totalFrames, 1);

% 进度条
h_wait2 = waitbar(0, '多方法联合降噪中', 'Name', '视频还原中');
frameCount = 0;

while hasFrame(vidReader_noisy) && hasFrame(vidReader_original)
    frameCount = frameCount + 1;
    waitbar(frameCount/totalFrames, h_wait2, sprintf('处理第 %d/%d 帧', frameCount, totalFrames));
    
    % 读取帧
    frame_original = im2double(readFrame(vidReader_original));
    frame_noisy = im2double(readFrame(vidReader_noisy));
    
    % =============== 多方法联合降噪 ===============
    restored_frames = cell(length(filterMethods), 1);
    psnr_values = zeros(length(filterMethods), 1);
    
    % 方法1：中值滤波（处理椒盐噪声）
    frame_median = zeros(size(frame_noisy));
    for c = 1:3
        frame_median(:,:,c) = medfilt2(frame_noisy(:,:,c), medianFilterWindow);
    end
    restored_frames{1} = frame_median;
    psnr_values(1) = psnr(frame_median, frame_original);
    
    % 方法2：双边滤波（保留边缘）
    frame_bilateral = imbilatfilt(frame_noisy, bilateralSigmaSpatial, bilateralSigmaRange);
    restored_frames{2} = frame_bilateral;
    psnr_values(2) = psnr(frame_bilateral, frame_original);
    
    % 方法3：自适应维纳滤波
    frame_adaptive = zeros(size(frame_noisy));
    for c = 1:3
        frame_adaptive(:,:,c) = wiener2(frame_noisy(:,:,c), adaptiveFilterSize, adaptiveNoiseVariance);
    end
    restored_frames{3} = frame_adaptive;
    psnr_values(3) = psnr(frame_adaptive, frame_original);
    
    % 方法4：小波降噪（可选）
    try
        frame_wavelet = zeros(size(frame_noisy));
        for c = 1:3
            [cA, cH, cV, cD] = dwt2(frame_noisy(:,:,c), 'db4');
            % 软阈值去噪
            threshold = sqrt(2*log(numel(cA))) * median(abs(cD(:))) / 0.6745;
            cA = wthresh(cA, 's', threshold);
            cH = wthresh(cH, 's', threshold);
            cV = wthresh(cV, 's', threshold);
            cD = wthresh(cD, 's', threshold);
            frame_wavelet(:,:,c) = idwt2(cA, cH, cV, cD, 'db4', size(frame_noisy(:,:,c)));
        end
        restored_frames{4} = frame_wavelet;
        psnr_values(4) = psnr(frame_wavelet, frame_original);
    catch
        restored_frames{4} = frame_median;
        psnr_values(4) = psnr_values(1);
    end
    
    % 选择最佳方法或融合方法
    [bestPSNR, bestIdx] = max(psnr_values);
    
    if bestIdx <= length(filterMethods)
        frame_restored = restored_frames{bestIdx};
        videoInfo.methodsUsed{frameCount} = filterMethods{bestIdx};
    else
        % 如果小波方法不可用，使用中值滤波
        frame_restored = frame_median;
        videoInfo.methodsUsed{frameCount} = 'median';
    end
    
    % =============== 后处理增强 ===============
    % 边缘增强
    if edgeEnhancement
        for c = 1:3
            % 使用Sobel算子检测边缘
            edgeMask = edge(frame_restored(:,:,c), 'sobel', 0.1);
            % 增强边缘
            frame_restored(:,:,c) = frame_restored(:,:,c) + sharpeningFactor * 0.2 * double(edgeMask);
        end
    end
    
    % 限制像素值范围
    frame_restored = min(max(frame_restored, 0), 1);
    
    % 计算评估指标
    videoInfo.restoredPSNR(frameCount) = psnr(frame_restored, frame_original);
    videoInfo.restoredSSIM(frameCount) = ssim(frame_restored, frame_original);
    
    % 写入还原帧
    writeVideo(vidWriter_restored, frame_restored);
end

close(h_wait2);
close(vidWriter_restored);

%% ===================== 5. 视频处理效果评估 =====================
disp('【步骤5/10】评估视频处理效果...');
% 计算平均指标
avg_psnr_noisy = mean(videoInfo.noisyPSNR(1:frameCount));
avg_psnr_restored = mean(videoInfo.restoredPSNR(1:frameCount));
avg_ssim_noisy = mean(videoInfo.ssimValues(1:frameCount));
avg_ssim_restored = mean(videoInfo.restoredSSIM(1:frameCount));

psnr_improvement = avg_psnr_restored - avg_psnr_noisy;
ssim_improvement = avg_ssim_restored - avg_ssim_noisy;

% 统计使用的降噪方法
methodsSummary = struct();
for i = 1:length(videoInfo.methodsUsed)
    if ~isempty(videoInfo.methodsUsed{i})
        methodName = videoInfo.methodsUsed{i};
        if isfield(methodsSummary, methodName)
            methodsSummary.(methodName) = methodsSummary.(methodName) + 1;
        else
            methodsSummary.(methodName) = 1;
        end
    end
end

fprintf('\n视频处理效果评估：\n');
fprintf('噪声视频平均PSNR：%.2f dB\n', avg_psnr_noisy);
fprintf('还原视频平均PSNR：%.2f dB\n', avg_psnr_restored);
fprintf('PSNR提升幅度：%.2f dB\n', psnr_improvement);
fprintf('\n噪声视频平均SSIM：%.4f\n', avg_ssim_noisy);
fprintf('还原视频平均SSIM：%.4f\n', avg_ssim_restored);
fprintf('SSIM提升幅度：%.4f\n', ssim_improvement);

fprintf('\n降噪方法使用统计：\n');
methodNames = fieldnames(methodsSummary);
for i = 1:length(methodNames)
    count = methodsSummary.(methodNames{i});
    percentage = 100 * count / frameCount;
    fprintf('  %s: %d帧 (%.1f%%)\n', methodNames{i}, count, percentage);
end

% 可视化对比
figure('Color','white','Position',[100 100 1200 800]);

% PSNR对比
subplot(2,3,1);
t = 1:frameCount;
plot(t, videoInfo.noisyPSNR(1:frameCount), 'r-', 'LineWidth',1.2);
hold on;
plot(t, videoInfo.restoredPSNR(1:frameCount), 'g-', 'LineWidth',1.2);
xlabel('帧数', 'FontSize',11);
ylabel('PSNR（dB）', 'FontSize',11);
title('PSNR对比', 'FontSize',12);
legend(sprintf('噪声视频（%.2f dB）', avg_psnr_noisy), ...
       sprintf('还原视频（%.2f dB）', avg_psnr_restored), ...
       'Location','best');
grid on;
xlim([1 frameCount]);

% SSIM对比
subplot(2,3,2);
plot(t, videoInfo.ssimValues(1:frameCount), 'r-', 'LineWidth',1.2);
hold on;
plot(t, videoInfo.restoredSSIM(1:frameCount), 'g-', 'LineWidth',1.2);
xlabel('帧数', 'FontSize',11);
ylabel('SSIM', 'FontSize',11);
title('结构相似性对比', 'FontSize',12);
legend(sprintf('噪声视频（%.4f）', avg_ssim_noisy), ...
       sprintf('还原视频（%.4f）', avg_ssim_restored), ...
       'Location','best');
grid on;
xlim([1 frameCount]);

% 方法使用分布
subplot(2,3,3);
if ~isempty(methodNames)
    pieData = zeros(length(methodNames), 1);
    pieLabels = cell(length(methodNames), 1);
    for i = 1:length(methodNames)
        pieData(i) = methodsSummary.(methodNames{i});
        pieLabels{i} = sprintf('%s\n%d帧 (%.1f%%)', methodNames{i}, pieData(i), 100*pieData(i)/sum(pieData));
    end
    pie(pieData, pieLabels);
    title('降噪方法使用分布', 'FontSize',12);
end

% 展示示例帧对比
subplot(2,3,4);
sampleFrame = min(50, frameCount);
vidReader_noisy = VideoReader(noisyVideoOnlyFile);
vidReader_restored = VideoReader(restoredVideoOnlyFile);

% 定位到示例帧
for i = 1:sampleFrame
    frame_noisy_example = readFrame(vidReader_noisy);
    frame_restored_example = readFrame(vidReader_restored);
end

imshow([frame_noisy_example, frame_restored_example]);
title(sprintf('第%d帧：噪声(左) vs 还原(右)', sampleFrame), 'FontSize',12);

% 性能提升统计
subplot(2,3,5);
improvements = [psnr_improvement, ssim_improvement*100]; % SSIM放大100倍便于显示
bar(improvements, 'FaceColor', [0.2, 0.6, 0.8]);
set(gca, 'XTickLabel', {'PSNR提升(dB)', 'SSIM提升(x100)'});
ylabel('改进幅度', 'FontSize',11);
title('降噪性能提升统计', 'FontSize',12);
grid on;

% 噪声与还原帧直方图对比
subplot(2,3,6);
noisyHist = imhist(rgb2gray(frame_noisy_example));
restoredHist = imhist(rgb2gray(frame_restored_example));
plot(noisyHist, 'r-', 'LineWidth', 1.5);
hold on;
plot(restoredHist, 'g-', 'LineWidth', 1.5);
xlabel('灰度值', 'FontSize',11);
ylabel('像素数量', 'FontSize',11);
title('灰度直方图对比', 'FontSize',12);
legend('噪声帧', '还原帧', 'Location','best');
grid on;

saveas(gcf, 'video_enhanced_evaluation.png');
close(gcf);

%% ===================== 6-9. 音频处理（保持不变） =====================
% [保持原有的音频处理代码不变，从步骤6到步骤9]
% 这里省略重复的音频处理代码，保持原样

%% ===================== 6. 音频处理：添加高斯白噪声 =====================
disp('【步骤6/10】对音频添加高斯白噪声...');
% 读取原始音频
[y, Fs] = audioread(originalAudioFile);
if size(y, 2) > 1
    y = mean(y, 2); % 转换为单声道
end

% 归一化
y = y / max(abs(y(:)));

% 计算噪声功率并生成高斯白噪声
signal_power = mean(y.^2, 1);
noise_power = signal_power / (10^(snr_dB/10));
noise = sqrt(noise_power) .* randn(size(y));

% 叠加噪声并裁剪
y_noisy = y + noise;
y_noisy(y_noisy > 1) = 1;
y_noisy(y_noisy < -1) = -1;

% 保存噪声音频
audiowrite(noisyAudioFile, y_noisy, Fs);

%% ===================== 7. 音频处理：降噪滤波 =====================
disp('【步骤7/10】对噪声音频进行降噪滤波...');
% 读取噪声音频
x = y_noisy;  
len_x = length(x);

% 设计IIR椭圆低通滤波器
F_pass = audioFilterPass;    % 通带截止频率 (Hz)
F_stop = audioFilterStop;    % 阻带截止频率 (Hz)
F_total = 8000;              % 滤波器设计参考频率 (Hz)
A_stop = 100;                % 阻带衰减 (dB)
A_pass = 1;                  % 通带波纹 (dB)

% 模拟域频率转换
wp = 2*pi*F_pass/F_total;
ws = 2*pi*F_stop/F_total;

% 计算椭圆滤波器阶数和截止频率
[n, wn] = ellipord(wp, ws, A_pass, A_stop, 's');
% 设计模拟椭圆低通滤波器
[b, a] = ellip(n, A_pass, A_stop, wn, 's');
% 双线性变换转换为数字滤波器
[B, A] = bilinear(b, a, 1);

% 对音频信号进行滤波处理
y_filtered = filter(B, A, x);
y_filtered = y_filtered / max(abs(y_filtered));  % 归一化

%% ===================== 8. 音频处理：频谱减法 =====================
disp('【步骤8/10】对滤波后音频进行频谱减法...');
% 对滤波后的信号做傅里叶变换
Y_filtered = fft(y_filtered);
amp_Y = abs(Y_filtered);
phase_Y = angle(Y_filtered);

% 幅值减去设定值，保证非负
amp_Y_sub = max(amp_Y - audioSubtractValue, 0);

% 重构频谱
Y_subtracted = amp_Y_sub .* exp(1j * phase_Y);

% 逆傅里叶变换回时域
y_subtracted = real(ifft(Y_subtracted));
y_subtracted = y_subtracted / max(abs(y_subtracted));  % 归一化

% 保存去噪音频
audiowrite(restoredAudioFile, y_subtracted, Fs);

%% ===================== 9. 音频处理效果可视化 =====================
disp('【步骤9/10】可视化音频处理效果...');
% 绘制原始音频和噪声音频对比
t_audio = (0:len_x-1)/Fs;

figure('Color','white','Position',[50 50 1200 800]);

% 原始音频时域
subplot(3,3,1);
plot(t_audio, y);
title('原始音频时域波形');
xlabel('时间 (s)');
ylabel('幅值');
grid on;

% 原始音频频域
Y_original = fft(y);
freq_axis = (0:len_x-1)*Fs/len_x;
subplot(3,3,2);
plot(freq_axis(1:len_x/2), abs(Y_original(1:len_x/2)));
title('原始音频频谱');
xlabel('频率 (Hz)');
ylabel('幅度');
xlim([0 4000]);
grid on;

% 噪声音频时域
subplot(3,3,4);
plot(t_audio, y_noisy);
title('噪声音频时域波形');
xlabel('时间 (s)');
ylabel('幅值');
grid on;

% 噪声音音频域
Y_noisy = fft(y_noisy);
subplot(3,3,5);
plot(freq_axis(1:len_x/2), abs(Y_noisy(1:len_x/2)));
title('噪声音音频谱');
xlabel('频率 (Hz)');
ylabel('幅度');
xlim([0 4000]);
grid on;

% 去噪音频时域
subplot(3,3,7);
plot(t_audio, y_subtracted);
title('去噪音频时域波形');
xlabel('时间 (s)');
ylabel('幅值');
grid on;

% 去噪音频频域
Y_restored = fft(y_subtracted);
subplot(3,3,8);
plot(freq_axis(1:len_x/2), abs(Y_restored(1:len_x/2)));
title('去噪音频频谱');
xlabel('频率 (Hz)');
ylabel('幅度');
xlim([0 4000]);
grid on;

% 滤波器频率响应
[h, w] = freqz(B, A);
subplot(3,3,3);
plot(w*Fs/(2*pi), abs(h));
title('IIR低通滤波器幅频响应');
xlabel('频率 (Hz)');
ylabel('幅度');
grid on;

% 频谱减法效果
subplot(3,3,6);
plot(freq_axis(1:len_x/2), amp_Y(1:len_x/2), 'b', 'LineWidth', 1.5);
hold on;
plot(freq_axis(1:len_x/2), amp_Y_sub(1:len_x/2), 'r', 'LineWidth', 1.5);
title('频谱减法效果');
xlabel('频率 (Hz)');
ylabel('幅度');
legend('滤波后', '减法后', 'Location', 'best');
xlim([0 4000]);
grid on;

% 音频对比（局部）
subplot(3,3,9);
segment = 1:min(5000, len_x);
plot(t_audio(segment), y(segment), 'b', 'LineWidth', 1);
hold on;
plot(t_audio(segment), y_noisy(segment), 'r', 'LineWidth', 0.5);
plot(t_audio(segment), y_subtracted(segment), 'g', 'LineWidth', 1);
title('音频波形对比（局部）');
xlabel('时间 (s)');
ylabel('幅值');
legend('原始', '噪声', '去噪', 'Location', 'best');
grid on;

saveas(gcf, 'audio_processing_evaluation.png');
close(gcf);

%% ===================== 10. 音视频合并 =====================
disp('【步骤10/10】合并音视频...');

% 检查FFmpeg是否可用
[ffmpegStatus, ~] = system('ffmpeg -version');
if ffmpegStatus == 0
    fprintf('✅ 检测到FFmpeg，开始合并音视频...\n');
    
    % 合并噪声视频和音频
    fprintf('正在合并噪声视频和音频...\n');
    cmd1 = sprintf('ffmpeg -y -i "%s" -i "%s" -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -shortest "%s"', ...
                  noisyVideoOnlyFile, noisyAudioFile, noisyVideoWithAudioFile);
    [status1, result1] = system(cmd1);
    
    if status1 == 0 && exist(noisyVideoWithAudioFile, 'file')
        fprintf('✅ 噪声视频合并成功！\n');
    else
        fprintf('❌ 噪声视频合并失败：%s\n', result1);
    end
    
    % 合并还原视频和音频
    fprintf('正在合并还原视频和音频...\n');
    cmd2 = sprintf('ffmpeg -y -i "%s" -i "%s" -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -shortest "%s"', ...
                  restoredVideoOnlyFile, restoredAudioFile, restoredVideoWithAudioFile);
    [status2, result2] = system(cmd2);
    
    if status2 == 0 && exist(restoredVideoWithAudioFile, 'file')
        fprintf('✅ 还原视频合并成功！\n');
    else
        fprintf('❌ 还原视频合并失败：%s\n', result2);
    end
    
    if status1 == 0 && status2 == 0
        fprintf('✅ 音视频合并成功！\n');
        mergeSuccess = true;
    else
        fprintf('⚠️  部分合并失败\n');
        mergeSuccess = false;
    end
    
else
    fprintf('❌ 未检测到FFmpeg，无法自动合并音视频\n');
    fprintf('请从 https://ffmpeg.org 下载FFmpeg并添加到系统路径\n');
    fprintf('或使用以下命令手动合并：\n');
    fprintf('ffmpeg -i "%s" -i "%s" -c:v copy -c:a aac "%s"\n', ...
            noisyVideoOnlyFile, noisyAudioFile, noisyVideoWithAudioFile);
    fprintf('ffmpeg -i "%s" -i "%s" -c:v copy -c:a aac "%s"\n', ...
            restoredVideoOnlyFile, restoredAudioFile, restoredVideoWithAudioFile);
    mergeSuccess = false;
end

%% ===================== 11. 最终结果展示 =====================
disp(' ');
disp('🎉 全流程处理完成！生成文件清单：');
disp('【视频文件】');
fprintf('  1. 噪声视频（无音频）：%s\n', noisyVideoOnlyFile);
fprintf('  2. 还原视频（无音频）：%s\n', restoredVideoOnlyFile);

if mergeSuccess
    fprintf('  3. 噪声视频（带噪声音频）：%s\n', noisyVideoWithAudioFile);
    fprintf('  4. 还原视频（带去噪音频）：%s\n', restoredVideoWithAudioFile);
else
    fprintf('  3. 噪声视频（带噪声音频）：需要手动合并\n');
    fprintf('  4. 还原视频（带去噪音频）：需要手动合并\n');
end

disp('【音频文件】');
fprintf('  5. 原始提取音频：%s\n', originalAudioFile);
fprintf('  6. 噪声音频：%s\n', noisyAudioFile);
fprintf('  7. 去噪音频：%s\n', restoredAudioFile);
disp('【评估图表】');
fprintf('  8. 视频PSNR评估图：video_enhanced_evaluation.png\n');
fprintf('  9. 音频处理评估图：audio_processing_evaluation.png\n');

% 显示视频处理效果总结
fprintf('\n📊 视频处理效果总结：\n');
fprintf('  噪声视频平均PSNR：%.2f dB\n', avg_psnr_noisy);
fprintf('  还原视频平均PSNR：%.2f dB\n', avg_psnr_restored);
fprintf('  PSNR提升：%.2f dB\n', psnr_improvement);
fprintf('  SSIM提升：%.4f\n', ssim_improvement);

if ~mergeSuccess
    disp(' ');
    disp('⚠️ 自动合并失败，请手动合并以下文件：');
    disp('使用FFmpeg命令：');
    fprintf('ffmpeg -i "%s" -i "%s" -c:v copy -c:a aac "%s"\n', ...
            noisyVideoOnlyFile, noisyAudioFile, noisyVideoWithAudioFile);
    fprintf('ffmpeg -i "%s" -i "%s" -c:v copy -c:a aac "%s"\n', ...
            restoredVideoOnlyFile, restoredAudioFile, restoredVideoWithAudioFile);
    disp('或使用视频编辑软件（如Adobe Premiere、剪映等）');
end

disp('====================================================');