% 本脚本是GUI，图形化整个系统
function gui(cfg)
    % 单独调试主逻辑
    if nargin < 1 || isempty(cfg)
        cfg = config();
    end
    fig = figure('Name', 'OFDM通信系统链路仿真','NumberTitle', 'off','MenuBar','none', 'ToolBar', 'none','Color', [0.94 0.94 0.94], 'Position', [120 80 1120 680]);
    controlPanel = uipanel('Parent', fig,'Title', '仿真参数','FontWeight', 'bold','Units', 'normalized', 'Position', [0.02 0.04 0.30 0.92]);
    plotPanel = uipanel('Parent', fig,'Title', '仿真结果', 'FontWeight', 'bold','Units', 'normalized', 'Position', [0.34 0.04 0.64 0.92]);
    ax = axes('Parent', plotPanel, 'Units', 'normalized', 'Position', [0.10 0.32 0.86 0.62]);
    grid(ax, 'on');xlabel(ax, 'Eb/N0 (dB)');ylabel(ax, 'Rate');title(ax, 'BER / SER / FER');
    statusBox = uicontrol( ...
        'Parent', plotPanel, ...
        'Style', 'edit', ...
        'Units', 'normalized', ...
        'Position', [0.10 0.05 0.86 0.20], ...
        'Max', 8, ...
        'Min', 0, ...
        'HorizontalAlignment', 'left', ...
        'Enable', 'inactive', ...
        'BackgroundColor', [1 1 1], ...
        'String', '设置参数后点击"开始仿真"。');
    y = 0.91;
    dy = 0.065;
    handles.bandwidth = addPopup(controlPanel, '系统带宽 (MHz)', {'3','5','7','10','15','20','25','30','35','40','45','50','60','70','80','90','100'}, num2str(cfg.Bandwidth), y);y = y - dy;
    handles.scs = addPopup(controlPanel, '子载波间隔 (kHz)', {'15', '30', '60'}, num2str(cfg.SCS), y);y = y - dy;
    handles.modulation = addPopup(controlPanel, '调制方式', {'BPSK', 'QPSK', '16QAM', '64QAM', '256QAM', '1024QAM'}, cfg.Modulation, y);y = y - dy;
    handles.channel = addPopup(controlPanel, '信道类型', {'Rayleigh', 'Rician', 'AWGN'}, cfg.ChannelType, y);y = y - dy;
    handles.equalizer = addPopup(controlPanel, '均衡算法', {'ZF', 'MMSE'}, cfg.ChannelEqualizer, y);y = y - dy;
    handles.estimation = addPopup(controlPanel, '信道估计', {'Ideal', 'LS', 'MMSE'}, cfg.ChannelEstimation, y);y = y - dy;
    handles.ebn0 = addEdit(controlPanel, "Eb/N0 (dB)", '0:2:30', y);y = y - dy;
    handles.frames = addEdit(controlPanel, '仿真帧数', num2str(cfg.NumFrames), y);y = y - dy;
    handles.symbols1frame = addEdit(controlPanel, 'OFDM符号数/帧', num2str(cfg.Symbols1Frame), y);y = y - dy;
    handles.riceK = addEdit(controlPanel, 'Rice K因子 (dB)', num2str(cfg.RiceKFactor), y);y = y - dy;
    handles.pilotSpacing = addEdit(controlPanel, '导频间隔', num2str(cfg.pilotSpacing), y);
    
    runButton = uicontrol('Parent', controlPanel, 'Style', 'pushbutton','Units', 'normalized','Position', [0.08 0.08 0.38 0.06],'String', '开始仿真', 'FontWeight', 'bold', 'Callback', @runSimulation);
    uicontrol('Parent', controlPanel,'Style', 'pushbutton', 'Units', 'normalized', 'Position', [0.54 0.08 0.38 0.06],'String', '恢复默认','Callback', @resetDefaults);
    updatePreview();
    set(handles.bandwidth, 'Callback', @(~, ~) updatePreview());
    set(handles.scs, 'Callback', @(~, ~) updatePreview());
    %% 子函数
    function runSimulation(~, ~)
       set(runButton, 'Enable', 'off');
       set(statusBox, 'String', '正在仿真，请稍候...');
       drawnow;
       try
          cfg = readGuiConfig();
          cfg.EnPlot = false;
          cfg.Verbose = false;
          results = ofdm(cfg);
          cla(ax);
          semilogy(ax, results.EbN0, max(results.BER, realmin), '-o', 'LineWidth', 1.5);hold(ax, 'on');
          semilogy(ax, results.EbN0, max(results.SER, realmin), '-s', 'LineWidth', 1.5);
          semilogy(ax, results.EbN0, max(results.FER, realmin), '-^', 'LineWidth', 1.5);hold(ax, 'off');
          grid(ax, 'on');xlabel(ax, 'Eb/N0 (dB)');ylabel(ax, 'Rate');legend(ax, {'BER', 'SER', 'FER'}, 'Location', 'southwest');
          title(ax, sprintf('%s, %s, %s, %s',cfg.Modulation, cfg.ChannelType, cfg.ChannelEqualizer, cfg.ChannelEstimation));
          set(statusBox, 'String', makeResultText(cfg, results));
      catch me
          set(statusBox, 'String', sprintf('错误：%s', me.message));
          errordlg(me.message, 'OFDM仿真错误');
      end
          set(runButton, 'Enable', 'on');
    end
    function resetDefaults(~, ~)
        setPopup(handles.bandwidth, num2str(cfg.Bandwidth));
        setPopup(handles.scs, num2str(cfg.SCS));
        setPopup(handles.modulation, cfg.Modulation);
        setPopup(handles.channel, cfg.ChannelType);
        setPopup(handles.equalizer, cfg.ChannelEqualizer);
        setPopup(handles.estimation, cfg.ChannelEstimation);
        set(handles.ebn0, 'String', numericVectorToString(cfg.EbN0));
        set(handles.frames, 'String', num2str(cfg.NumFrames));
        set(handles.symbols1frame, 'String', num2str(cfg.Symbols1Frame));
        set(handles.riceK, 'String', num2str(cfg.RiceKFactor));
        set(handles.pilotSpacing, 'String', num2str(cfg.pilotSpacing));
        updatePreview();
    end
    function cfg = readGuiConfig()
        cfg = config();
        cfg.Bandwidth = str2double(getPopup(handles.bandwidth));
        cfg.SCS = str2double(getPopup(handles.scs));
        cfg.Modulation = getPopup(handles.modulation);
        cfg.ChannelType = getPopup(handles.channel);
        cfg.ChannelEqualizer = getPopup(handles.equalizer);
        cfg.ChannelEstimation = getPopup(handles.estimation);
        cfg.EbN0 = parseNumericVector(get(handles.ebn0, 'String'));
        cfg.NumFrames = parsePositiveInteger(get(handles.frames, 'String'), '仿真帧数');
        cfg.Symbols1Frame = parsePositiveInteger(get(handles.symbols1frame, 'String'), 'OFDM符号数/帧');
        cfg.RiceKFactor = str2double(get(handles.riceK, 'String'));
        cfg.pilotSpacing = parsePositiveInteger(get(handles.pilotSpacing, 'String'), '导频间隔');

        if isempty(cfg.EbN0) || any(isnan(cfg.EbN0))
            error('Eb/N0 输入格式错误，例如 0:5:30 或 0 5 10 15。');
        end

        if isnan(cfg.RiceKFactor)
            error('Rice K因子必须是数值。');
        end
    end
    function updatePreview()
        try
            bw = str2double(getPopup(handles.bandwidth));
            scs = str2double(getPopup(handles.scs));
            [nrb, nsc, nfft, fsMHz] = previewOfdmParameters(bw, scs);
            text = sprintf(['参数预览：\n', ...
                'Bandwidth = %g MHz, SCS = %g kHz\n', ...
                'NRB = %d, 有效子载波 = %d\n', ...
                'FFTSize = %d, 采样率 = %.2f MHz'], ...
                bw, scs, nrb, nsc, nfft, fsMHz);
            set(statusBox, 'String', text);
        catch me
            set(statusBox, 'String', sprintf('参数预览错误：%s', me.message));
        end
    end
end

%% 子子函数
function h = addPopup(parent, labelText, items, defaultValue, y)
    uicontrol('Parent', parent,'Style', 'text', 'Units', 'normalized','Position', [0.08 y 0.40 0.035], 'HorizontalAlignment', 'left','String', labelText);
    h = uicontrol('Parent', parent, 'Style', 'popupmenu', 'Units', 'normalized', 'Position', [0.52 y 0.40 0.045], 'String', items);
    setPopup(h, defaultValue);
end

function h = addEdit(parent, labelText, value, y)
    uicontrol('Parent', parent,'Style', 'text','Units', 'normalized','Position', [0.08 y 0.40 0.035],'HorizontalAlignment', 'left','String', labelText);
    
    h = uicontrol('Parent', parent,'Style', 'edit','Units', 'normalized','Position', [0.52 y 0.40 0.045],'BackgroundColor', [1 1 1],'String', value);
end

function value = getPopup(h)
    items = get(h, 'String');
    if ischar(items)
        items = cellstr(items);
    end
    value = items{get(h, 'Value')};
end

function setPopup(h, value)
    items = get(h, 'String');
    if ischar(items)
        items = cellstr(items);
    end
    idx = find(strcmpi(items, value), 1);
    if isempty(idx)
        idx = 1;
    end
    set(h, 'Value', idx);
end

function values = parseNumericVector(text)
    text = strtrim(char(text));
    if contains(text, ':')
        parts = strsplit(text, ':');
        nums = cellfun(@str2double, parts);
        if numel(nums) == 2
            values = nums(1):nums(2);
        elseif numel(nums) == 3
            values = nums(1):nums(2):nums(3);
        else
            values = NaN;
        end
    else
        text = regexprep(text, '[\[\],;]', ' ');
        values = sscanf(text, '%f').';
    end
end

function value = parsePositiveInteger(text, labelText)
    value = str2double(text);
    if isnan(value) || value <= 0 || fix(value) ~= value
        error('%s必须是正整数', labelText);
    end
end

function text = numericVectorToString(values)
    text = strtrim(sprintf('%g ', values));
end

function [nrb, nsc, nfft, fsMHz] = previewOfdmParameters(bandwidth, scs)
    tableBandwidth = [3 5 7 10 15 20 25 30 35 40 45 50 60 70 80 90 100];
    tableSCS = [15 30 60];
    tableNRB = [ ...
        15 25 35 52 79 106 133 160 188 216 242 270 NaN NaN NaN NaN NaN; ...
        NaN 11 NaN 24 38 51 65 78 92 106 119 133 162 189 217 245 273; ...
        NaN NaN NaN 11 18 24 31 38 44 51 58 65 79 93 107 121 135];
    
    iBW = find(tableBandwidth == bandwidth, 1);
    iSCS = find(tableSCS == scs, 1);
    
    if isempty(iBW) || isempty(iSCS)
        error('带宽或子载波间隔不在表中');
    end
    nrb = tableNRB(iSCS, iBW);
    if isnan(nrb)
        error('该带宽和子载波间隔组合不支持');
    end
    
    nsc = nrb*12;
    nfft = 2^nextpow2(nsc);
    fsMHz = nfft*scs*1e3/1e6;
end

function text = makeResultText(cfg, results)
    lines = cell(1, numel(results.EbN0) + 5);
    lines{1} = sprintf('NRB=%d, NSC=%d, NFFT=%d, NCP=%d, 带宽:%.2f MHz', ...
        results.Params.NRB, results.Params.NSP, ...
        results.Params.NFFT, results.Params.CPLength, ...
        results.Params.SampleRate/1e6);
    lines{2} = sprintf('调制:%s, 信道:%s, 信道均衡:%s, 信道估计:%s', ...
        results.Config.Modulation, results.Config.ChannelType, ...
        results.Config.ChannelEqualizer, results.Config.ChannelEstimation);
    lines{3} = ' ';
    lines{4} = 'Eb/N0(dB)        BER           SER           FER        Frames';
    
    for i = 1:numel(results.EbN0)
        lines{i + 4} = sprintf('%8.2f   %11.4e  %11.4e  %11.4e  %6d', ...
            results.EbN0(i), results.BER(i), results.SER(i), ...
            results.FER(i), cfg.NumFrames);
    end
    text = sprintf('%s\n', lines{:});
end