clear, close all, 
dt = 0.0001; 
t = 0:dt:1; 
fc=input('Please input fc:'); % 请输入载波频率
fd=input('Please input fd:'); % 请输入低频频率
fa=input('Please input fa:'); % 请输入频偏
g = square(2*pi*fd*t,50); 
figure; 
subplot(2,1,1); plot(t,g,'r'); axis([0 1 -1.5 1.5]); title(strcat(' 低频调制信号，频率为fd=',int2str(fd),'Hz')); ylabel('幅度'); 
gs=cumsum(g)*dt; % 对 g(t)积分，得到连续的三角波相位 
rfsk=3*cos(2*pi*fc*t+2*pi*fa*gs); % 正确的铁路移频信号，在 fc±fa 上下边频间切换，
 %切换的频率为 fd（即方波频率），且保持相位连续
subplot(2,1,2); plot(t,rfsk); title('移频信号时域波形'); xlabel('t(秒)'); ylabel('幅度');

df = 0.1; % 频率间隔
f = fc-6*fd : df : fc+6*fd; % 拟计算的频率范围，根据理论频谱可知，第5个旁瓣后的幅值，基本趋于零了。 
RFSK=rfsk*exp(-1i*t'*2*pi*f)*dt; % 傅里叶变换
Xa=abs(RFSK); % 复数求模
figure; 
plot(f,Xa); title('铁路移频信号频谱'); xlabel('频率(Hz)'); ylabel('幅度'); % 幅度频谱

% 使用 findpeaks 函数找到所有峰值及其位置
[peaks, peak_locations] = findpeaks(Xa);% 对峰值幅度进行降序排序
[sorted_peaks, sort_indices] = sort(peaks, 'descend');
% 取排序后前3个峰值的位置索引
top3_peak_indices = peak_locations(sort_indices(1:3));
% 获取这3个峰值对应的频率
peak_freq1 = f(top3_peak_indices(1));
peak_freq2 = f(top3_peak_indices(2));
peak_freq3 = f(top3_peak_indices(3));
% 计算低频频率的可能值fdl
fdl(1) = abs(peak_freq1 - peak_freq2);
fdl(2) = abs(peak_freq1 - peak_freq3);
fdl(3) = abs(peak_freq2 - peak_freq3);
% 计算低频频率的估计值fdfinal
fdfinal = fdl(1);
for i = 2:3
    if(fdl(i)<fdfinal)
        fdfinal = fdl(i);
    end
end
% 比较估计值与设定值
fprintf('设定的低频频率 fd: %f Hz\n', fd);
fprintf('估计的低频频率 fd: %f Hz\n', fdfinal);
% 判定解调程序的正确性
if abs(fd - fdfinal) < 0.5 % 设定一个小的容差
    fprintf('解调程序编写正确。\n');
else
    fprintf('解调程序编写可能有误。\n');
end