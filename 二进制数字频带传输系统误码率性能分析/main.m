student_id = 2023112108;
Eb_N0 = mod(student_id,5) : 1 : mod(student_id,5)+8; % 信噪比范围
%Eb_N0 = -1 : 1 : 11; % 信噪比范围
bits = (mod(2023112108,100)+1)*1e5;                  % 总比特数
%bits = 7e7; % 总比特数,建议虚拟内存给到200GB才能跑完
alfa = mod(floor(student_id/10),10)/20+0.2;          % 升余弦系数：0.2

% 通用系统参数
sps = 16;          % 每符号抽样数
Rs = 1;            % 符号速率 (sym/s)
span = 16;         % 滤波器跨度（符号数）
% 升余弦滤波器设计（能量归一化）
h_tx = rcosdesign(alfa, span, sps);     
h_tx = h_tx / sqrt(sum(h_tx.^2));       
h_rx = h_tx;       % 接收匹配滤波器
filter_delay = length(h_tx) - 1;

% 生成通用发送比特流
tx_bits = randi([0, 1], 1, bits);       

%% ====================== 2ASK 仿真 ======================
% 2ASK参数
Es_ask = 1;               % 符号能量
Eb_ask = Es_ask/2;        % 平均比特能量
tx_symbols_ask = tx_bits; % 2ASK映射

% 升采样与滤波
tx_up_ask = zeros(1, bits * sps);
tx_up_ask(1:sps:end) = tx_symbols_ask;
tx_ok_ask = filter(h_tx, 1, tx_up_ask);
valid_start = filter_delay + 1;
valid_end = length(tx_ok_ask) - filter_delay;

% 遍历Eb/N0计算误码率
num_EbN0 = length(Eb_N0);
error_theo_ask = zeros(1, num_EbN0);
error_ideal_ask = zeros(1, num_EbN0);
error_lim_ask = zeros(1, num_EbN0);

for idx = 1:num_EbN0
    EbN0_dB = Eb_N0(idx);
    EbN0_line = 10^(EbN0_dB/10);
    N0 = Eb_ask / EbN0_line;          
    noise_var = N0 / 2;             

    % 带限AWGN信道
    noise_lim = sqrt(noise_var) * randn(size(tx_ok_ask));
    rx_lim = tx_ok_ask + noise_lim;
    rx_ok = filter(h_rx, 1, rx_lim);
    
    sample_idx = valid_start : sps : valid_end;
    rx_samples = rx_ok(sample_idx);
    valid_len = length(sample_idx);
    tx_bits_valid = tx_bits(1:valid_len);
    
    % 2ASK判决
    rx_bits_lim = (rx_samples > 0.5);
    error_count = sum(tx_bits_valid ~= rx_bits_lim);
    error_lim_ask(idx) = max(error_count / valid_len, 1/valid_len);

    % 理想AWGN信道
    noise_ideal = sqrt(noise_var) * randn(size(tx_symbols_ask(1:valid_len)));
    rx_symbols_ideal = tx_symbols_ask(1:valid_len) + noise_ideal;
    rx_bits_ideal = (rx_symbols_ideal > 0.5);
    error_count = sum(tx_bits_valid ~= rx_bits_ideal);
    error_ideal_ask(idx) = max(error_count / valid_len, 1/valid_len);

    % 2ASK理论误码率
    error_theo_ask(idx) = 0.5 * erfc(sqrt(EbN0_line/2));
end

% 绘制2ASK图
figure('Color','w','Position',[100,100,800,600]);
semilogy(Eb_N0, error_theo_ask, 'b-o', 'LineWidth',1.8, 'MarkerSize',6, 'DisplayName','理论误码率');
hold on;
semilogy(Eb_N0, error_lim_ask, 'r-*', 'LineWidth',1.8, 'MarkerSize',6, 'DisplayName','带限AWGN');
semilogy(Eb_N0, error_ideal_ask, 'g-s', 'LineWidth',1.8, 'MarkerSize',6, 'DisplayName','理想AWGN');
grid on; grid minor;
xlabel('Eb/N0 (dB)','FontSize',12);
ylabel('误码率','FontSize',12);
title('二进制数字频带传输系统误码率性能分析（2ASK，学号：2023112108）','FontSize',14);
legend('Location','best','FontSize',10);
set(gca,'FontSize',11);

%% ======================  2FSK 仿真 ======================
% 2FSK核心参数
fs = sps * Rs;      % 采样频率
Tb = 1/Rs;          % 比特周期
f0 = 0.5 * Rs;      % 频率1 
f1 = 1.5 * Rs;      % 频率2 保证正交性 (f1-f0=Rs)
Es_fsk = 1;         % 符号能量
Eb_fsk = Es_fsk;    % 比特能量 

% 生成正交信号
t_symbol = (0:sps-1)/fs;
ref0 = sqrt(2*Es_fsk/Tb) * cos(2*pi*f0*t_symbol);  % 符号0信号
ref1 = sqrt(2*Es_fsk/Tb) * cos(2*pi*f1*t_symbol);  % 符号1信号

% 生成理想2FSK信号
tx_ideal_fsk = zeros(1, bits * sps);
for k = 1:bits
    start_idx = (k-1)*sps + 1;
    if tx_bits(k) == 0
        tx_ideal_fsk(start_idx:start_idx+sps-1) = ref0;
    else
        tx_ideal_fsk(start_idx:start_idx+sps-1) = ref1;
    end
end

% 生成带限2FSK信号
phase = zeros(1, bits * sps);
for k = 1:bits
    if tx_bits(k) == 0
        freq = f0;
    else
        freq = f1;
    end
    t_segment = (0:sps-1)/fs;
    phase((k-1)*sps+1:k*sps) = 2*pi*freq*t_segment;
end
tx_lim_fsk = sqrt(2*Es_fsk/Tb) * cos(phase);

% 初始化误码率数组
error_theo_fsk = zeros(1, num_EbN0);
error_ideal_fsk = zeros(1, num_EbN0);
error_lim_fsk = zeros(1, num_EbN0);

% 遍历信噪比计算误码率
for idx = 1:num_EbN0
    EbN0_dB = Eb_N0(idx);
    EbN0_line = 10^(EbN0_dB/10);
    N0 = Eb_fsk / EbN0_line;          
    sigma2 = N0 * fs / 2;  

    % 理想AWGN信道
    noise_ideal = sqrt(sigma2) * randn(size(tx_ideal_fsk));
    rx_ideal = tx_ideal_fsk + noise_ideal;
    rx_bits_ideal = zeros(1, bits);
    for k = 1:bits
        start_idx = (k-1)*sps + 1;
        end_idx = k*sps;
        seg = rx_ideal(start_idx:end_idx);
        corr0 = sum(seg .* ref0);
        corr1 = sum(seg .* ref1);
        rx_bits_ideal(k) = (corr1 > corr0);
    end
    errors_ideal = sum(rx_bits_ideal ~= tx_bits);
    error_ideal_fsk(idx) = max(errors_ideal / bits, 1/bits); % 防止0值

    % 带限AWGN信道
    noise_band = sqrt(sigma2) * randn(size(tx_lim_fsk));
    rx_band = tx_lim_fsk + noise_band;
    rx_bits_band = zeros(1, bits);
    for k = 1:bits
        start_idx = (k-1)*sps + 1;
        end_idx = k*sps;
        seg = rx_band(start_idx:end_idx);
        corr0 = sum(seg .* ref0);
        corr1 = sum(seg .* ref1);
        rx_bits_band(k) = (corr1 > corr0);
    end
    errors_band = sum(rx_bits_band ~= tx_bits);
    error_lim_fsk(idx) = max(errors_band / bits, 1/bits);  % 防止0值

    % 2FSK相干解调理论误码率
    error_theo_fsk(idx) = 0.5 * erfc(sqrt(EbN0_line/2));
end

% 绘制2FSK图
figure('Color','w','Position',[100,100,800,600]);
semilogy(Eb_N0, error_theo_fsk, 'b-o', 'LineWidth',1.8, 'MarkerSize',6, 'DisplayName','理论误码率');
hold on;
semilogy(Eb_N0, error_lim_fsk, 'r-*', 'LineWidth',1.8, 'MarkerSize',6, 'DisplayName','带限AWGN');
semilogy(Eb_N0, error_ideal_fsk, 'g-s', 'LineWidth',1.8, 'MarkerSize',6, 'DisplayName','理想AWGN');
grid on; grid minor;
xlabel('Eb/N0 (dB)','FontSize',12);
ylabel('误码率','FontSize',12);
title('二进制数字频带传输系统误码率性能分析（2FSK，学号：2023112108）','FontSize',14);
legend('Location','best','FontSize',10);
set(gca,'FontSize',11);

%% ======================  2PSK 仿真 ======================
% 2PSK参数
Es_psk = 1;
Eb_psk = Es_psk;
tx_symbols_psk = 2*tx_bits - 1;  % 2PSK映射

% 升采样与滤波
tx_up_psk = zeros(1, bits * sps);
tx_up_psk(1:sps:end) = tx_symbols_psk;
tx_ok_psk = filter(h_tx, 1, tx_up_psk);

% 遍历Eb/N0计算误码率
error_theo_psk = zeros(1, num_EbN0);
error_ideal_psk = zeros(1, num_EbN0);
error_lim_psk = zeros(1, num_EbN0);

for idx = 1:num_EbN0
    EbN0_dB = Eb_N0(idx);
    EbN0_line = 10^(EbN0_dB/10);
    N0 = Eb_psk / EbN0_line;          
    noise_var = N0 / 2;             

    % 带限AWGN信道
    noise_lim = sqrt(noise_var) * randn(size(tx_ok_psk));
    rx_lim = tx_ok_psk + noise_lim;
    rx_ok = filter(h_rx, 1, rx_lim);
    sample_idx = valid_start : sps : valid_end;
    rx_samples = rx_ok(sample_idx);
    valid_len = length(sample_idx);
    tx_bits_valid = tx_bits(1:valid_len);
    
    % 2PSK判决
    rx_bits_lim = (rx_samples > 0);
    error_count = sum(tx_bits_valid ~= rx_bits_lim);
    error_lim_psk(idx) = max(error_count / valid_len, 1/valid_len);

    % 理想AWGN信道
    noise_ideal = sqrt(noise_var) * randn(size(tx_symbols_psk(1:valid_len)));
    rx_symbols_ideal = tx_symbols_psk(1:valid_len) + noise_ideal;
    rx_bits_ideal = (rx_symbols_ideal > 0);
    error_count = sum(tx_bits_valid ~= rx_bits_ideal);
    error_ideal_psk(idx) = max(error_count / valid_len, 1/valid_len);

    % 2PSK理论误码率
    error_theo_psk(idx) = 0.5 * erfc(sqrt(EbN0_line));
end

% 绘制2PSK图
figure('Color','w','Position',[100,100,800,600]);
semilogy(Eb_N0, error_theo_psk, 'b-o', 'LineWidth',1.8, 'MarkerSize',6, 'DisplayName','理论误码率（2PSK）');
hold on;
semilogy(Eb_N0, error_lim_psk, 'r-*', 'LineWidth',1.8, 'MarkerSize',6, 'DisplayName','带限AWGN');
semilogy(Eb_N0, error_ideal_psk, 'g-s', 'LineWidth',1.8, 'MarkerSize',6, 'DisplayName','理想AWGN');
grid on; grid minor;
xlabel('Eb/N0 (dB)','FontSize',12);
ylabel('误码率','FontSize',12);
title('二进制数字频带传输系统误码率性能分析（2PSK，学号：2023112108）','FontSize',14);
legend('Location','best','FontSize',10);
set(gca,'FontSize',11);

%% ======================  DPSK 仿真 ======================
% DPSK参数
Es_dpsk = 1;
Eb_dpsk = Es_dpsk;

% 差分编码
tx_dpsk_symbols = zeros(1, bits);
tx_dpsk_symbols(1) = 1;  % 初始参考符号
for n = 2:bits
    tx_dpsk_symbols(n) = xor(tx_bits(n-1), tx_dpsk_symbols(n-1));
end
tx_dpsk_symbols = 2*tx_dpsk_symbols - 1;  % 映射为双极性符号

% 升采样与滤波
tx_upsampled_dpsk = zeros(1, bits * sps);
tx_upsampled_dpsk(1:sps:end) = tx_dpsk_symbols;
tx_filtered_dpsk = filter(h_tx, 1, tx_upsampled_dpsk);

% 遍历Eb/N0计算误码率
error_theo_dpsk = zeros(1, num_EbN0);
error_ideal_dpsk = zeros(1, num_EbN0);
error_lim_dpsk = zeros(1, num_EbN0);

for idx = 1:num_EbN0
    EbN0_dB = Eb_N0(idx);
    EbN0_line = 10^(EbN0_dB/10);
    N0 = Eb_dpsk / EbN0_line;          
    noise_var = N0 / 2;             

    % 带限AWGN信道
    noise_lim = sqrt(noise_var) * randn(size(tx_filtered_dpsk));
    rx_lim = tx_filtered_dpsk + noise_lim;
    rx_ok = filter(h_rx, 1, rx_lim);
    sample_idx = valid_start : sps : valid_end;
    rx_samples = rx_ok(sample_idx);
    valid_len = length(sample_idx);
    tx_bits_valid = tx_bits(1:valid_len-1);  % 差分判决少1比特
    
    % DPSK差分判决
    rx_diff = rx_samples(2:end) .* rx_samples(1:end-1);
    rx_bits_lim = (rx_diff < 0);
    error_count = sum(tx_bits_valid ~= rx_bits_lim);
    error_lim_dpsk(idx) = max(error_count / length(tx_bits_valid), 1/length(tx_bits_valid));

    % 理想AWGN信道
    noise_ideal = sqrt(noise_var) * randn(size(tx_dpsk_symbols(1:valid_len)));
    rx_symbols_ideal = tx_dpsk_symbols(1:valid_len) + noise_ideal;
    rx_diff_ideal = rx_symbols_ideal(2:end) .* rx_symbols_ideal(1:end-1);
    rx_bits_ideal = (rx_diff_ideal < 0);
    error_count = sum(tx_bits_valid ~= rx_bits_ideal);
    error_ideal_dpsk(idx) = max(error_count / length(tx_bits_valid), 1/length(tx_bits_valid));

    % DPSK理论误码率
    error_theo_dpsk(idx) =2* 0.5 * erfc(sqrt(EbN0_line))-2* 0.5 * erfc(sqrt(EbN0_line))* 0.5 * erfc(sqrt(EbN0_line));
end

% 绘制DPSK图
figure('Color','w','Position',[100,100,800,600]);
semilogy(Eb_N0, error_theo_dpsk, 'b-o', 'LineWidth',1.8, 'MarkerSize',6, 'DisplayName','理论误码率（DPSK）');
hold on;
semilogy(Eb_N0, error_lim_dpsk, 'r-*', 'LineWidth',1.8, 'MarkerSize',6, 'DisplayName','带限AWGN');
semilogy(Eb_N0, error_ideal_dpsk, 'g-s', 'LineWidth',1.8, 'MarkerSize',6, 'DisplayName','理想AWGN');
grid on; grid minor;
xlabel('Eb/N0 (dB)','FontSize',12);
ylabel('误码率','FontSize',12);
title('二进制数字频带传输系统误码率性能分析（DPSK，学号：2023112108）','FontSize',14);
legend('Location','best','FontSize',10);
set(gca,'FontSize',11);

%% ====================== 结果图1：理论值+理想AWGN ======================
figure('Color','w','Position',[100,100,900,700]);
% 2ASK
semilogy(Eb_N0, error_theo_ask, 'b-o', 'LineWidth',1.5, 'MarkerSize',5, 'DisplayName','2ASK-理论');
hold on;
semilogy(Eb_N0, error_ideal_ask, 'b--s', 'LineWidth',1.5, 'MarkerSize',5, 'DisplayName','2ASK-理想AWGN');
% 2FSK
semilogy(Eb_N0, error_theo_fsk, 'r-o', 'LineWidth',1.5, 'MarkerSize',5, 'DisplayName','2FSK-理论');
semilogy(Eb_N0, error_ideal_fsk, 'r--s', 'LineWidth',1.5, 'MarkerSize',5, 'DisplayName','2FSK-理想AWGN');
% 2PSK
semilogy(Eb_N0, error_theo_psk, 'g-o', 'LineWidth',1.5, 'MarkerSize',5, 'DisplayName','2PSK-理论');
semilogy(Eb_N0, error_ideal_psk, 'g--s', 'LineWidth',1.5, 'MarkerSize',5, 'DisplayName','2PSK-理想AWGN');
% DPSK
semilogy(Eb_N0, error_theo_dpsk, 'm-o', 'LineWidth',1.5, 'MarkerSize',5, 'DisplayName','DPSK-理论');
semilogy(Eb_N0, error_ideal_dpsk, 'm--s', 'LineWidth',1.5, 'MarkerSize',5, 'DisplayName','DPSK-理想AWGN');

grid on; grid minor;
xlabel('Eb/N0 (dB)','FontSize',12);
ylabel('误码率','FontSize',12);
title('四种调制方式理论误码率与在理想AWGN信道下误码率对比（学号：2023112108）','FontSize',14);
legend('Location','best','FontSize',9);
set(gca,'FontSize',11);

%% ====================== 结果图2：理论值+带限AWGN ======================
figure('Color','w','Position',[100,100,900,700]);
% 2ASK
semilogy(Eb_N0, error_theo_ask, 'b-o', 'LineWidth',1.5, 'MarkerSize',5, 'DisplayName','2ASK-理论');
hold on;
semilogy(Eb_N0, error_lim_ask, 'b--*', 'LineWidth',1.5, 'MarkerSize',5, 'DisplayName','2ASK-带限AWGN');
% 2FSK
semilogy(Eb_N0, error_theo_fsk, 'r-o', 'LineWidth',1.5, 'MarkerSize',5, 'DisplayName','2FSK-理论');
semilogy(Eb_N0, error_lim_fsk, 'r--*', 'LineWidth',1.5, 'MarkerSize',5, 'DisplayName','2FSK-带限AWGN');
% 2PSK
semilogy(Eb_N0, error_theo_psk, 'g-o', 'LineWidth',1.5, 'MarkerSize',5, 'DisplayName','2PSK-理论');
semilogy(Eb_N0, error_lim_psk, 'g--*', 'LineWidth',1.5, 'MarkerSize',5, 'DisplayName','2PSK-带限AWGN');
% DPSK
semilogy(Eb_N0, error_theo_dpsk, 'm-o', 'LineWidth',1.5, 'MarkerSize',5, 'DisplayName','DPSK-理论');
semilogy(Eb_N0, error_lim_dpsk, 'm--*', 'LineWidth',1.5, 'MarkerSize',5, 'DisplayName','DPSK-带限AWGN');

grid on; grid minor;
xlabel('Eb/N0 (dB)','FontSize',12);
ylabel('误码率','FontSize',12);
title('四种调制方式理论误码率与在带限AWGN信道下误码率对比（学号：2023112108）','FontSize',14);
legend('Location','best','FontSize',9);
set(gca,'FontSize',11);

%% ====================== 结果输出 ======================
fprintf('=== 最终仿真结果汇总（学号：%d）===\n', student_id);
fprintf('------------------------------------------------------------------------------------------------------------------------------------------------------------------------\n');
fprintf('Eb/N0(dB)\t2ASK-理论\t2ASK-带限AWGN\t2ASK-理想AWGN\t2FSK-理论\t2FSK-带限AWGN\t2FSK-理想AWGN\t2PSK-理论\t2PSK-带限AWGN\t2PSK-理想AWGN\tDPSK-理论\tDPSK-带限AWGN\tDPSK-理想AWGN\n');
fprintf('------------------------------------------------------------------------------------------------------------------------------------------------------------------------\n');
for idx = 1:num_EbN0
    fprintf('%.1f\t\t%.4e\t%.4e\t%.4e\t%.4e\t%.4e\t%.4e\t%.4e\t%.4e\t%.4e\t%.4e\t%.4e\t%.4e\n', ...
        Eb_N0(idx), ...
        error_theo_ask(idx), error_lim_ask(idx), error_ideal_ask(idx), ...
        error_theo_fsk(idx), error_lim_fsk(idx), error_ideal_fsk(idx), ...
        error_theo_psk(idx), error_lim_psk(idx), error_ideal_psk(idx), ...
        error_theo_dpsk(idx), error_lim_dpsk(idx), error_ideal_dpsk(idx));
end