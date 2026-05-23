% 仿真系统主逻辑
function results = ofdm(cfg)
    % 单独调试主逻辑
    if nargin < 1 || isempty(cfg)
        cfg = config();
    end
    if ~isempty(cfg.RandomSeed)
        rng(cfg.RandomSeed);
    end
    % ---------------------------- 根据5G标准补充仿真参数 ----------------------------%
    cfg = CheckConfig(cfg);
    % 构造OFDM参数结构体
    params = OfdmParams(cfg);
    fprintf("OFDM仿真: 信道：%s 调制：%s 带宽：%g MHz SCS=%g kHz" + ...
        " 信道均衡：%s 信道估计：%s NRB=%d NSP=%d NFFT=%d NCP=%d\n", ...
        cfg.ChannelType, cfg.Modulation, cfg.Bandwidth, cfg.SCS, ...
        cfg.ChannelEqualizer, cfg.ChannelEstimation, params.NRB, params.NSP, ...
        params.NFFT, params.CPLength);
    
    % ---------------------------- OFDM核心仿真逻辑 ----------------------------------%
    % 初始化性能指标数组
    numEbN0 = numel(cfg.EbN0);
    BER = zeros(1, numEbN0);       % 误比特率 BER
    SER = zeros(1, numEbN0);       % 误符号率 SER
    FER = zeros(1, numEbN0);       % 误帧率 FER
    
    for iEbN0 = 1:numEbN0
        % 计算噪声功率
        ebn0Db = cfg.EbN0(iEbN0);
        ebn0Linear = 10.^(ebn0Db/10);
        noiseVar = 1/(params.BitsPerSymbol*ebn0Linear);
        % 单信噪比下统计误帧、误码、误比特数
        bitErrors = 0;
        symbolErrors = 0;
        frameErrors = 0;
        % 单信噪比下总传输码元、比特数
        totalBits = 0;
        totalSymbols = 0;
        % 单信噪比下发送所有帧
        for iFrame = 1:cfg.NumFrames
            % 发送1帧
            frame = simulateOneFrame(cfg, params, noiseVar);
            % 1帧错误统计
            bitErrors = bitErrors + frame.BitErrors;
            symbolErrors = symbolErrors + frame.SymbolErrors;
            frameErrors = frameErrors + double(frame.BitErrors > 0);
            totalBits = totalBits + frame.TotalBits;
            totalSymbols = totalSymbols + frame.TotalSymbols;
        end
        % 统计单信噪比下误帧率、误符号率、误比特率
        BER(iEbN0) = bitErrors / max(totalBits, 1);
        SER(iEbN0) = symbolErrors / max(totalSymbols, 1);
        FER(iEbN0) = frameErrors / max(iFrame, 1);
        % 打印单信噪比下的结果
        if cfg.Verbose
            fprintf("Eb/N0=%5.1f dB: BER=%9.3e, SER=%9.3e, FER=%9.3e, frames=%d\n", ...
                ebn0Db, BER(iEbN0), SER(iEbN0), FER(iEbN0), iFrame);
        end
    end
    
    % ---------------------------- 仿真结果输出与绘图 ---------------------------------%
    results = struct();
    results.Config = cfg;
    results.Params = params;
    results.EbN0 = cfg.EbN0;
    results.BER = BER;
    results.SER = SER;
    results.FER = FER;
    results.NRB = params.NRB;
    results.NSP = params.NSP;
    results.NFFT = params.NFFT;
    results.CPLength = params.CPLength;
    % 绘图
    if cfg.EnPlot
        plotResults(results);
    end
end


%% 子函数调用部分
%=================================== 检查默认配置 =======================================%
function cfg = CheckConfig(cfg)
    % 类型确认
    cfg.Bandwidth = double(cfg.Bandwidth);
    cfg.SCS = double(cfg.SCS);
    cfg.EbN0 = double(cfg.EbN0);
    cfg.NumFrames = double(cfg.NumFrames);
    cfg.Symbols1Frame = double(cfg.Symbols1Frame);
    cfg.ChannelType = string(cfg.ChannelType);
    cfg.Modulation = string(cfg.Modulation);
    cfg.ChannelEqualizer = string(cfg.ChannelEqualizer);
    cfg.ChannelEstimation = string(cfg.ChannelEstimation);
    cfg.PathDelays = double(cfg.PathDelays(:).');
    cfg.PathGains = double(cfg.PathGains(:).');

    % AWGN理想高斯信道无衰落
    if strcmpi(cfg.ChannelType, "AWGN")
        cfg.PathDelays = 0;
        cfg.PathGains = 0;
        cfg.MaxDopplerShift = 0;
    end

    % 检查配置
    if numel(cfg.PathDelays) ~= numel(cfg.PathGains)
        error("检查到多径效应时间拓展与幅度衰落的数组长度不一致！");
    end
    if any(cfg.PathDelays < 0) || any(mod(cfg.PathDelays, 1) ~= 0)
        error("检查到时间拓展有负数或小数！");
    end
    if cfg.Symbols1Frame < 1 || mod(cfg.Symbols1Frame, 1) ~= 0
        error("检查到1帧码元数为负数或小数！");
    end
    if cfg.NumFrames < 1 || mod(cfg.NumFrames, 1) ~= 0
        error("检查到总码元数为负数或小数！");
    end
    if ~any(strcmpi(cfg.ChannelType, ["AWGN", "Rayleigh", "Rician"]))
        error("检查到不支持的信道类型: %s", cfg.ChannelType);
    end
    if ~any(strcmpi(cfg.ChannelEqualizer, ["ZF", "MMSE"]))
        error("检查到不支持的信道均衡: %s", cfg.ChannelEqualizer);
    end
    if ~any(strcmpi(cfg.ChannelEstimation, ["Ideal", "LS", "MMSE"]))
        error("检查到不支持的信道估计: %s", cfg.ChannelEstimation);
    end
end

% ================================== 根据5G标准解析OFDM参数配置 ====================================== %
function params = OfdmParams(cfg)
    % 根据 3GPP 38.104 Table 5.3.2-1 配置NRB
    tableBandwidth = [3 5 7 10 15 20 25 30 35 40 45 50 60 70 80 90 100];
    tableSCS = [15 30 60];
    tableNRB = [ ...
        15 25 35 52 79 106 133 160 188 216 242 270 NaN NaN NaN NaN NaN; ...
        NaN 11 NaN 24 38 51 65 78 92 106 119 133 162 189 217 245 273; ...
        NaN NaN NaN 11 18 24 31 38 44 51 58 65 79 93 107 121 135];
    
    iBW = find(tableBandwidth == cfg.Bandwidth, 1);
    iSCS = find(tableSCS == cfg.SCS, 1);
    if isempty(iBW) || isempty(iSCS) || isnan(tableNRB(iSCS, iBW))
        error("输入系统带宽/子载波间隔不合法: %g MHz，%g kHz", cfg.Bandwidth, cfg.SCS);
    end
    % 资源块数NRB
    NRB = tableNRB(iSCS, iBW);
    % 子载波数
    NSP = NRB * 12;
    % 自动计算FFT长度
    if isempty(cfg.NFFT)
        NFFT = 2 ^ nextpow2(NSP);
    else
        NFFT = double(cfg.NFFT);
    end
    if NFFT < NSP
        error("FFT长度必须大于NSP=%d", NSP);
    end
    % 循环前缀CP
    if isempty(cfg.CPLength)
        switch upper(string(cfg.CPLengthRatio))
        case "NORMAL"
            cpLength = round(NFFT * 1/16);
        case "EXTENDED"
            cpLength = round(NFFT * 1/8);
        otherwise
            error("输入循环前缀不合法：CPLengthRatio=%s",cfg.CPLengthRatio);
        end
    else
        cpLength = double(cfg.CPLength);
    end
    % NCP须大于信道最大时延
    maxDelay = max(cfg.PathDelays);
    if cpLength <= maxDelay
        cpLength = maxDelay + 1;
    end

    % 有效子载波的范围
    activeStart = floor((NFFT - NSP)/2) + 1;
    activeSubcarriers = (activeStart:(activeStart + NSP - 1)).';
    % 设置导频与数据位置
    if strcmpi(cfg.ChannelEstimation, "Ideal")
        pilotSubcarriers = zeros(0, 1);
        dataSubcarriers = (1:NSP).';
    else
        spacing = max(1, round(double(cfg.pilotSpacing)));
        pilotSubcarriers = (1:spacing:NSP).';
        if pilotSubcarriers(end) ~= NSP
            pilotSubcarriers = [pilotSubcarriers; NSP];
        end
        dataSubcarriers = setdiff((1:NSP).', pilotSubcarriers);
        if isempty(dataSubcarriers)
            error("导频太多导致数据放不下了！");
        end
    end

    % 调制方式
    modulation = upper(erase(string(cfg.Modulation), "-"));
    switch modulation
        case "BPSK"
            M = 2;
            bitsPerSymbol = 1;
            isPSK = true;
            phaseOffset = 0;
        case "QPSK"
            M = 4;
            bitsPerSymbol = 2;
            isPSK = true;
            phaseOffset = pi/4;
        case "16QAM"
            M = 16;
            bitsPerSymbol = 4;
            isPSK = false;
            phaseOffset = 0;
        case "64QAM"
            M = 64;
            bitsPerSymbol = 6;
            isPSK = false;
            phaseOffset = 0;
        case "256QAM"
            M = 256;
            bitsPerSymbol = 8;
            isPSK = false;
            phaseOffset = 0;
        case "1024QAM"
            M = 1024;
            bitsPerSymbol = 10;
            isPSK = false;
            phaseOffset = 0;
        otherwise
            error("不支持的调制方式: %s", modulation);
    end
    
    % 构造OFDM所有仿真所需参数结构体
    params = struct();
    params.NRB = NRB;
    params.NSP = NSP;
    params.NFFT = NFFT;
    params.CPLength = cpLength;
    params.SCS = cfg.SCS * 1e3;
    params.SampleRate = NFFT * cfg.SCS * 1e3;
    params.ActiveSubcarriers = activeSubcarriers;
    params.M = M;
    params.BitsPerSymbol = bitsPerSymbol;
    params.IsPSK = isPSK;
    params.PhaseOffset = phaseOffset;
    params.PilotSubcarriers = pilotSubcarriers;
    params.DataSubcarriers = dataSubcarriers;
    params.SymbolLength = NFFT + cpLength;
    params.FrameSamples = params.SymbolLength * cfg.Symbols1Frame;
end

% ===================================== 发送1帧核心逻辑 =================================== %
function frame = simulateOneFrame(cfg, params, noiseVar)
    numDataSymbols = numel(params.DataSubcarriers) * cfg.Symbols1Frame;
    numBits = numDataSymbols * params.BitsPerSymbol;
    % ---------------------------- 发射端 ----------------------------%
    txBits = randi([0 1], numBits, 1);
    % 调制
    txSymbols = modulateBits(txBits, params);
    % 构建资源表
    txGrid = zeros(params.NSP, cfg.Symbols1Frame);
    txGrid(params.DataSubcarriers, :) = reshape(txSymbols, numel(params.DataSubcarriers), []);
    % 导频值（非理想信道时）
    if ~isempty(params.PilotSubcarriers)
        txGrid(params.PilotSubcarriers, :) = cfg.PilotSymbol;
    end
    % ---------------------------- 信道传输 --------------------------%
    [rxGrid, channelResponse] = transmitOfdm(txGrid, params, cfg, noiseVar);
    % ---------------------------- 接收端 ----------------------------%
    % 信道估计
    if strcmpi(cfg.ChannelEstimation, "Ideal")
        hEstimate = channelResponse;
    else
        hEstimate = estimateChannel(rxGrid, txGrid, params.PilotSubcarriers, ...
            cfg.ChannelEstimation, noiseVar, cfg);
    end
    % 信道均衡
    eqGrid = equalizeGrid(rxGrid, hEstimate, noiseVar, cfg.ChannelEqualizer);
    rxSymbols = eqGrid(params.DataSubcarriers, :);
    rxBits = demodulateSymbols(rxSymbols(:), params);
    % ---------------------------- 错误统计 --------------------------%
    rxBits = rxBits(1:numel(txBits));
    bitErrorVector = txBits ~= rxBits;
    symbolErrorVector = any(reshape(bitErrorVector, params.BitsPerSymbol, []), 1);
    % 构造单帧结果结构体
    frame = struct();
    frame.BitErrors = sum(bitErrorVector);
    frame.SymbolErrors = sum(symbolErrorVector);
    frame.TotalBits = numel(txBits);
    frame.TotalSymbols = numDataSymbols;
end

% ================================== 绘图 ====================================== %
function plotResults(results)
    figure("Name", "OFDM通信系统链路仿真");
    semilogy(results.EbN0, max(results.BER, realmin), "-o", "LineWidth", 1.5);hold on;
    semilogy(results.EbN0, max(results.SER, realmin), "-s", "LineWidth", 1.5);
    semilogy(results.EbN0, max(results.FER, realmin), "-^", "LineWidth", 1.5);grid on;
    xlabel("Eb/N0 (dB)");
    ylabel("Error Rate");
    legend("BER", "SER", "FER", "Location", "southwest");
    title(sprintf("%s, %s信道, %s均衡, %s估计", ...
        results.Config.Modulation, results.Config.ChannelType, ...
        results.Config.ChannelEqualizer, results.Config.ChannelEstimation));
end


%% 子子函数调用部分
% ================================ 调制 ======================================== %
function symbols = modulateBits(bits, params)
    if params.IsPSK
        symbols = pskmod(bits, params.M, params.PhaseOffset, "gray", "InputType", "bit");
    else
        symbols = qammod(bits, params.M, "gray", "InputType", "bit", "UnitAveragePower", true);
    end
    symbols = symbols(:);
end

% ================================ 解调 ======================================== %
function bits = demodulateSymbols(symbols, params)
    if params.IsPSK
        bits = pskdemod(symbols, params.M, params.PhaseOffset, "gray", "OutputType", "bit");
    else
        bits = qamdemod(symbols, params.M, "gray", "OutputType", "bit", "UnitAveragePower", true);
    end
    bits = bits(:);
end

% ============================== 信道传输 ======================================= %
function [rxGrid, channelResponse] = transmitOfdm(txGrid, params, cfg, noiseVar)
    % 加入循环前缀
    gridCentered = zeros(params.NFFT, cfg.Symbols1Frame);
    gridCentered(params.ActiveSubcarriers, :) = txGrid;
    txNoCp = ifft(ifftshift(gridCentered, 1), params.NFFT, 1) * sqrt(params.NFFT);
    txWithCp = [txNoCp(end-params.CPLength+1:end, :); txNoCp];
    txWaveform = txWithCp(:);
    
    % AWGN信道无衰落
    if strcmpi(cfg.ChannelType, "AWGN")
        rxChannel = txWaveform;
        channelResponse = ones(params.NSP, cfg.Symbols1Frame);
    else % 瑞利/莱斯信道衰落
        switch upper(cfg.ChannelType)
            case "RAYLEIGH"
                % 瑞利：删除直射径
                rayleighDelays = cfg.PathDelays(2:end);
                delays = round(rayleighDelays(:));
                rayleighDelays = rayleighDelays / params.SampleRate;
                rayleighGains  = cfg.PathGains(2:end);
                channel = comm.RayleighChannel( ...
                    "SampleRate", params.SampleRate, ...
                    "PathDelays", rayleighDelays, ...
                    "AveragePathGains", rayleighGains, ...
                    "MaximumDopplerShift", double(cfg.MaxDopplerShift), ...
                    "NormalizePathGains", true, ...
                    "PathGainsOutputPort", true);
            case "RICIAN"
                % 莱斯：保留直射径
                ricianDelays = cfg.PathDelays / params.SampleRate;
                delays = round(cfg.PathDelays(:));
                channel = comm.RicianChannel( ...
                    "SampleRate", params.SampleRate, ...
                    "PathDelays", ricianDelays, ...
                    "AveragePathGains", cfg.PathGains, ...
                    "KFactor", double(cfg.RiceKFactor), ...
                    "MaximumDopplerShift", double(cfg.MaxDopplerShift), ...
                    "NormalizePathGains", true, ...
                    "PathGainsOutputPort", true);
            otherwise
                error("不支持的信道衰落类型 %s", cfg.ChannelType);
        end
        [rxChannel, pathGains] = channel(txWaveform);
        maxDelay = max(delays);
        channelResponse = zeros(params.NSP, cfg.Symbols1Frame);
        
        for iSymbol = 1:cfg.Symbols1Frame
            sampleIndex = (iSymbol - 1) * params.SymbolLength + params.CPLength + 1;
            sampleIndex = min(sampleIndex, size(pathGains, 1));
            gains = pathGains(sampleIndex, :).';
            impulse = zeros(maxDelay + 1, 1);
            for iPath = 1:numel(delays)
                impulse(delays(iPath) + 1) = impulse(delays(iPath) + 1) + gains(iPath);
            end
            hPadded = zeros(params.NFFT, 1);
            hPadded(1:numel(impulse)) = impulse;
            hFreq = fftshift(fft(hPadded, params.NFFT));
            channelResponse(:, iSymbol) = hFreq(params.ActiveSubcarriers);
        end
    end
    % 生成噪声
    noise = sqrt(noiseVar/2) * (randn(size(rxChannel)) + 1i * randn(size(rxChannel)));
    rxWaveform = rxChannel + noise;
    % 接收信号
    rxWaveform = rxWaveform(1:params.FrameSamples);
    rxMatrix = reshape(rxWaveform, params.SymbolLength, cfg.Symbols1Frame);
    % 去除循环前缀
    rxNoCp = rxMatrix(params.CPLength+1:end, :);
    rxCentered = fftshift(fft(rxNoCp, params.NFFT, 1) / sqrt(params.NFFT), 1);
    rxGrid = rxCentered(params.ActiveSubcarriers, :);
end

% ================================= 信道估计 ======================================= %
function hEstimate = estimateChannel(rxGrid, txGrid, pilotSubcarriers, method, noiseVar, cfg)
    if isempty(pilotSubcarriers)
        error("信道估计不合法！");
    end
    [numSubcarriers, numSymbols] = size(rxGrid);
    allSubcarriers = (1:numSubcarriers).';
    hEstimate = zeros(numSubcarriers, numSymbols, "like", rxGrid);
    for iSymbol = 1:numSymbols
        txPilot = txGrid(pilotSubcarriers, iSymbol);
        rxPilot = rxGrid(pilotSubcarriers, iSymbol);
        txPilot(abs(txPilot) < eps) = eps;
        hPilotLS = rxPilot ./ txPilot;
        if isscalar(pilotSubcarriers)
            hInterp = repmat(hPilotLS, numSubcarriers, 1);
        else
            hInterp = interp1(pilotSubcarriers, hPilotLS, allSubcarriers, "linear", "extrap");
        end
        if strcmpi(method, "MMSE")
            channelPower = max(mean(abs(hInterp).^2), eps);
            hInterp = hInterp * (channelPower / (channelPower + noiseVar));
        end
        hEstimate(:, iSymbol) = hInterp;
    end
end

% ================================= 信道均衡 ======================================= %
function equalizedGrid = equalizeGrid(rxGrid, hEstimate, noiseVar, equalizer)
    switch upper(string(equalizer))
        case "ZF"
            hSafe = hEstimate;
            hSafe(abs(hSafe) < eps) = eps;
            equalizedGrid = rxGrid ./ hSafe;
        case "MMSE"
            equalizedGrid = conj(hEstimate) .* rxGrid ./ (abs(hEstimate).^2 + noiseVar);
        otherwise
            error("信道均衡不合法：%s", equalizer);
    end
end
