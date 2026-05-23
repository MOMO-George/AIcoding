student_id = 2023112108;
%Eb_N0 = mod(student_id,5) : 1 : mod(student_id,5)+8; % 信噪比范围
Eb_N0 = -1 : 1 : 11; % 信噪比范围
%bits = (mod(student_id,100)+1)*1e5;                  % 总比特数
bits = 5*1e7;        % 总比特数，建议虚拟内存开到60GB，不然跑不完
alfa = mod(floor(student_id/10),10)/20+0.2;          % 升余弦滚降系数

% 基带传输核心参数（双极性不归零码）
sps = 16;          % 每符号抽样数
Rs = 1;            % 符号速率 
Tb = 1/Rs;         % 比特周期
Es = 1;            % 符号能量
Eb = Es;           % 双极性不归零码比特能量与符号能量相等

% 升余弦滤波器设计
span = 16;         % 滤波器跨度（符号数）
h_tx = rcosdesign(alfa, span, sps);     % 发送端升余弦滤波器原型
h_tx = h_tx / sqrt(sum(h_tx.^2));       % 能量归一化，保证信号功率稳定
h_rx = h_tx;       % 接收端匹配滤波器

% 生成基带发送信号（双极性不归零码）
tx_bits = randi([0, 1], 1, bits);       % 生成0/1随机比特流
tx_nrz = 2 * tx_bits - 1;               % 双极性不归零码映射

% 带限信道的预计算升采样与发送滤波
tx_up = zeros(1, bits * sps);
tx_up(1:sps:end) = tx_nrz;              % 升采样
tx_ok = filter(h_tx, 1, tx_up);         % 限制信号带宽，避免码间串扰
filter_delay = length(h_tx) - 1;        % 滤波器群时延
valid_start = filter_delay + 1;         % 有效信号起始位置
valid_end = length(tx_ok) - filter_delay; % 有效信号结束位置

% 遍历Eb/N0计算误码率
num_EbN0 = length(Eb_N0);
error_lim = zeros(1, num_EbN0);           % 带限AWGN信道仿真误码率
error_ideal = zeros(1, num_EbN0);         % 理想AWGN信道仿真误码率
error_theo = zeros(1, num_EbN0);          % 理论误码率
error_count_lim = zeros(1, num_EbN0);     % 带限信道误码数统计
error_count_ideal = zeros(1, num_EbN0);   % 理想信道误码数统计

for idx = 1:num_EbN0
    EbN0_dB = Eb_N0(idx);
    EbN0_line = 10^(EbN0_dB/10); % dB转线性值
    N0 = Eb / EbN0_line;         % 噪声功率谱密度
    noise_var = N0 / 2;          % 高斯白噪声方差

    % ---------------------- 带限AWGN信道 ----------------------
    noise_lim = sqrt(noise_var) * randn(size(tx_ok)); % 生成带限信道噪声
    rx_lim = tx_ok + noise_lim;                       % 发送信号叠加噪声
    rx_ok = filter(h_rx, 1, rx_lim);                  % 接收匹配滤波
    % 抽样判决，恢复基带符号
    sample_idx = valid_start : sps : valid_end;
    rx_samples = rx_ok(sample_idx);
    valid_len = length(sample_idx);       % 有效恢复符号长度
    tx_bits_valid = tx_bits(1:valid_len); % 截取对应长度的原始比特（用于误码统计）
    % NRZ码相干判决
    rx_bits_lim = (rx_samples > 0);
    error_count_lim(idx) = sum(tx_bits_valid ~= rx_bits_lim); % 统计误码数
    % 避免误码率为0
    error_lim(idx) = max(error_count_lim(idx) / valid_len, 1/valid_len);

    % ---------------------- 理想AWGN信道 ----------------------
    noise_ideal = sqrt(noise_var) * randn(size(tx_nrz(1:valid_len))); % 理想信道噪声
    rx_symbols_ideal = tx_nrz(1:valid_len) + noise_ideal; % 基带符号直接叠加噪声
    rx_bits_ideal = (rx_symbols_ideal > 0); % 直接判决
    error_count_ideal(idx) = sum(tx_bits_valid ~= rx_bits_ideal); % 统计误码数
    error_ideal(idx) = max(error_count_ideal(idx) / valid_len, 1/valid_len);

    % ---------------------- 基带NRZ信号理论误码率 ----------------------
    % 理论公式：AWGN信道下基带NRZ相干解调误码率
    error_theo(idx) = 0.5 * erfc(sqrt(EbN0_line));
end

% 结果可视化
figure('Color','w','Position',[100,100,800,600]);
semilogy(Eb_N0, error_theo, 'b-o', 'LineWidth',1.8, 'MarkerSize',6, 'DisplayName','理论误码率');
hold on;
semilogy(Eb_N0, error_lim, 'r-*', 'LineWidth',1.8, 'MarkerSize',6, 'DisplayName','带限AWGN');
semilogy(Eb_N0, error_ideal, 'g-s', 'LineWidth',1.8, 'MarkerSize',6, 'DisplayName','理想AWGN');
grid on; grid minor;
xlabel('Eb/N0 (dB)','FontSize',12);
ylabel('误码率（BER）','FontSize',12);
title('数字基带传输系统误码率性能（基带双极性不归零信号，学号：2023112108）','FontSize',14);
legend('Location','best','FontSize',10);
set(gca,'FontSize',11);

% 结果输出
fprintf('=== 数字基带传输系统仿真结果汇总（学号：%d）===\n', student_id);
fprintf('--------------------------------------------------------\n');
fprintf('Eb/N0(dB)\t理论BER（NRZ）\t带限AWGN BER\t理想AWGN BER\n');
fprintf('--------------------------------------------------------\n');
for idx = 1:num_EbN0
    ber_bandlim = error_lim(idx);
    ber_ideal = error_ideal(idx);
    fprintf('%.1f\t\t%.4e\t\t%.4e\t\t%.4e\n', ...
        Eb_N0(idx), error_theo(idx), ber_bandlim, ber_ideal);
end