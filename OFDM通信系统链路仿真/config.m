% 本函数为默认参数配置
function cfg = config()
cfg = struct();

cfg.ChannelType = "Rayleigh";       % 衰落信道类型，支持：Rayleigh, Rician，AWGN（AWGN理想高斯信道无衰落）
cfg.RiceKFactor = 6;                % 莱斯因子，单位dB（仅在莱斯信道下使能）
cfg.Modulation = "BPSK";           % 调制方式，支持：BPSK, QPSK, 16QAM, 64QAM, 256QAM, 1024QAM
cfg.Bandwidth = 20;                 % 系统带宽，单位MHz，支持：3，5，7，10，15，20，25，30，35，40，45，50，60，70，80，90，100
cfg.SCS = 30;                       % 子载波间隔，单位KHz，支持：15, 30, 60
cfg.ChannelEqualizer = "MMSE";      % 信道均衡算法，支持：ZF, MMSE
cfg.ChannelEstimation = "Ideal";    % 信道估计算法，支持：LS, MMSE，Ideal（Ideal理想信道无衰减）

cfg.NumFrames = 1000;     % 总帧数
cfg.Symbols1Frame = 14;  % 一帧里有多少个码元
cfg.EbN0 = 0:1:12;       % 信噪比，单位dB
cfg.NFFT = [];           % FFT长度，为空时程序自动计算最小长度，否则使用指定长度

cfg.CPLength = [];              % CP长度，为空时程序自动计算最小长度，否则使用指定长度
cfg.CPLengthRatio = "Normal";   % 自动计算CP时生效，Normal:一般前缀长度，Extended:扩展前缀长度
cfg.pilotSpacing = 4;           % 导频子载波间隔，每 4 个子载波 1 个导频；2 4 6 8
cfg.PilotSymbol = 1 + 0i;       % 导频值；(1 + 1i)/sqrt(2) exp(1i*pi/4)

cfg.PathDelays = [0 1];         % 多径效应的时延拓展；[0 1 3 5 7]
cfg.PathGains = [0 -3];         % 多径效应的幅度衰落；[0 -3 -6 -9 -12]
cfg.MaxDopplerShift = 0;        % 最大多普勒平移，单位：Hz；10 30 50

cfg.RandomSeed = 2026;   % 固定种子
cfg.EnPlot = true;       % 绘图使能
cfg.Verbose = true;      % 打印逐步仿真结果

end