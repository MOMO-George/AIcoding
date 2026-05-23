clear, close all, 
dt = 0.0001; 
t = 0:dt:1; 
fc=input('Please input fc:'); % 请输入载波频率
fd=input('Please input fd:'); % 请输入低频频率
fa=input('Please input fa:'); % 请输入频偏
g = square(2*pi*fd*t,50); 
gs = cumsum(g)*dt; % 对 g(t)积分，得到连续的三角波相位 
rfsk = 3*cos(2*pi*fc*t+2*pi*fa*gs); % 正确的铁路移频信号，在 fc±fa 上下边频间切换，
% 切换的频率为 fd（即方波频率），且保持相位连续

df = 0.1; %频率间隔
f = fc-6*fd : df : fc+6*fd; % 拟计算的频率范围，根据理论频谱可知，第5个旁瓣后的幅值，基本趋于零了。 
RFSK=rfsk*exp(-1i*t'*2*pi*f)*dt; %傅里叶变换
Xa=abs(RFSK); % 复数求模

% 信号抽样
Fs = input('请输入抽样频率 Fs=(不超过 10000Hz):');
% 先观察原信号频谱波形再来决定频率，可以试试 1000，150，100，70，50 等频率
Ts=1/Fs; 
N = fix(1/Ts); 
tn = 0:Ts:1; 
Ns = fix((0:N)*Ts/dt+1);
rfsk_samples = rfsk(Ns); % 抽样后的轨道移频信号，抽样频率Fs

figure;
subplot(4,1,1);plot(t,rfsk);title('原始移频信号时域波形');% 原始移频信号时域波形
subplot(4,1,2);
hold on;
stem(tn,rfsk_samples,'r-.');% 时域抽样信号波形
plot(t,rfsk,'g');title(strcat('时域抽样信号，抽样间隔Ts=',num2str(1/Fs)));xlabel('时间(s)')
hold off;

df2 = 0.1; % Hz 
f2 = -3*Fs/2:df2:3*Fs/2; % 此处的 f 取值范围，是根据下面 ws 的范围所确定的，
% 目的是使 FT 变换和 DTFT 变换的频谱图的横坐标范围一致。
RFSK=rfsk*exp(-1i*t'*2*pi*f2)*dt; % DTET的频谱
RFSK=abs(RFSK); 
% 希望计算的频率范围（-3pi, 3pi），方便展现频谱周期延拓效果（等价于DTFT的三个周期）
dw = 0.1*2*pi/Fs;
ws = -3*pi :dw:3*pi; 
RFSK_samplesDTFT= rfsk_samples *exp(-1i * (0:length(tn)-1)' *ws); % 抽样信号的DTFT变换
RFSK_samplesDTFT=abs(RFSK_samplesDTFT);

subplot(4,1,3);plot(f2,RFSK,'g');title('原始移频信号频谱');% 原始移频信号频谱
subplot(4,1,4);plot(f2,RFSK_samplesDTFT);title('抽样信号频谱');xlabel('频率(Hz)');
wc=pi*Fs;% 理想低通滤波器截止频率
sReconstruction = zeros(1,length(t));L=length(tn);


for i = 1:L % Sinc 函数插值
    sInterpolation= Ts*(wc)*rfsk_samples(i)*sinc((wc)*(t-(i-1)*Ts)/pi)/pi;
    sReconstruction = sReconstruction+sInterpolation;
end
error = abs(sReconstruction-rfsk); % 重构误差
figure;
subplot(2,1,1);plot(t,rfsk,t,sReconstruction,'--');title('时域波形');legend('原始信号','重构信号');
subplot(2,1,2);plot(t,error);title('重构误差');xlabel('时间t(秒)');