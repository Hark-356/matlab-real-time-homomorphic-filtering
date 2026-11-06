% =========================================================================
%  HOMOMORPHIC FILTERING — INTERACTIVE PARAMETER TUNER
%
%  Runs the live webcam feed with real-time parameter adjustment from
%  the MATLAB Command Window. After every 15 frames a prompt appears;
%  enter a command to adjust filter parameters and immediately observe
%  the effect on the output.
%
%  Controls (type in Command Window):
%    h <value>  — Set gammaH (e.g., "h 2.5")
%    l <value>  — Set gammaL (e.g., "l 0.3")
%    d <value>  — Set D0     (e.g., "d 50")
%    c <value>  — Set c      (e.g., "c 1.5")
%    r          — Reset to defaults
%    q          — Quit
%    (Enter)    — Continue with current settings
%
%  Run:
%    >> live_homomorphic_tuner
% =========================================================================

clear; close all; clc;

%% ---- Default parameters -------------------------------------------------
gammaL = 0.4;
gammaH = 2.0;
c_val  = 1.0;
D0     = 40;
scale  = 0.5;

fprintf('╔════════════════════════════════════════════════════╗\n');
fprintf('║    HOMOMORPHIC FILTER — INTERACTIVE TUNER         ║\n');
fprintf('╠════════════════════════════════════════════════════╣\n');
fprintf('║  Commands:                                         ║\n');
fprintf('║    h <val>  → set gammaH     l <val>  → set gammaL║\n');
fprintf('║    d <val>  → set D0         c <val>  → set c     ║\n');
fprintf('║    r        → reset defaults q        → quit      ║\n');
fprintf('║    (Enter)  → keep current parameters              ║\n');
fprintf('╚════════════════════════════════════════════════════╝\n\n');

%% ---- Initialize webcam --------------------------------------------------
try
    cam = webcam(1);
    cam.Resolution = cam.AvailableResolutions{1};
    fprintf('✓ Webcam: %s\n\n', cam.Name);
catch ME
    error('Webcam error: %s', ME.message);
end

%% ---- Get frame size -----------------------------------------------------
testFrame = imresize(snapshot(cam), scale);
[M, N] = size(rgb2gray(testFrame));

%% ---- Create display figure ----------------------------------------------
fig = figure('Name', 'Homomorphic Tuner', 'NumberTitle', 'off', ...
             'Color', [0.05 0.05 0.08], 'Position', [50 100 1200 500]);

hAx = gobjects(1,3);
hImg = gobjects(1,3);
titles = {'Original', 'Filter H(u,v)', 'Enhanced Output'};

for k = 1:3
    hAx(k) = subplot(1, 3, k, 'Parent', fig);
    title(hAx(k), titles{k}, 'Color', 'white', 'FontSize', 12, 'FontWeight', 'bold');
    set(hAx(k), 'XTick', [], 'YTick', [], 'Color', [0.08 0.08 0.12]);
    axes(hAx(k)); %#ok<LAXES>
    hImg(k) = imshow(zeros(M, N, 3, 'uint8'));
end

hParams = text(hAx(2), N/2, M-10, '', ...
    'Color', 'yellow', 'FontSize', 10, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
    'BackgroundColor', [0 0 0 0.6], 'Margin', 3);

hMetric = text(hAx(3), 5, M-10, '', ...
    'Color', [0 1 0.8], 'FontSize', 10, 'FontWeight', 'bold', ...
    'VerticalAlignment', 'bottom', ...
    'BackgroundColor', [0 0 0 0.6], 'Margin', 3);

drawnow;

%% ---- Main loop -----------------------------------------------------------
running = true;

while running && ishandle(fig)
    %-- Build filter for current parameters --------------------------------
    [u, v] = meshgrid(1:N, 1:M);
    cU = floor(N/2)+1; cV = floor(M/2)+1;
    D2 = (u-cU).^2 + (v-cV).^2;
    H = (gammaH - gammaL) .* (1 - exp(-c_val .* D2 ./ (D0^2))) + gammaL;

    %-- Display filter as colormap -----------------------------------------
    Hdisp = (H - min(H(:))) / (max(H(:)) - min(H(:)) + eps);
    HdispRGB = uint8(ind2rgb(uint8(Hdisp*255), parula(256)) * 255);

    %-- Process several frames with current params before asking -----------
    for f = 1:15
        if ~ishandle(fig); running = false; break; end

        rawFrame = imresize(snapshot(cam), scale);
        grayD    = im2double(rgb2gray(rawFrame));

        % Apply homomorphic filter
        enhanced = homomorphic_filter(grayD, gammaL, gammaH, c_val, D0);

        % Display
        set(hImg(1), 'CData', repmat(uint8(grayD*255), [1 1 3]));
        set(hImg(2), 'CData', HdispRGB);
        set(hImg(3), 'CData', repmat(uint8(enhanced*255), [1 1 3]));

        paramStr = sprintf('\\gamma_L=%.2f  \\gamma_H=%.2f\nc=%.2f  D_0=%d', ...
                           gammaL, gammaH, c_val, D0);
        set(hParams, 'String', paramStr);

        cir = std(enhanced(:)) / max(std(grayD(:)), eps);
        set(hMetric, 'String', sprintf('Contrast: %.2f×', cir));

        set(fig, 'Name', sprintf('γL=%.1f  γH=%.1f  c=%.1f  D0=%d  |  type h/l/d/c/r/q + Enter', ...
                 gammaL, gammaH, c_val, D0));
        drawnow limitrate;
    end

    if ~running; break; end

    %-- Get user input -----------------------------------------------------
    cmd = input(sprintf('[γL=%.2f γH=%.2f c=%.2f D0=%d] > ', gammaL, gammaH, c_val, D0), 's');
    cmd = strtrim(cmd);

    if isempty(cmd)
        continue;
    end

    switch cmd(1)
        case 'h'
            val = str2double(cmd(2:end));
            if ~isnan(val) && val > 0
                gammaH = val;
                fprintf('  → gammaH = %.2f\n', gammaH);
            end
        case 'l'
            val = str2double(cmd(2:end));
            if ~isnan(val) && val > 0
                gammaL = val;
                fprintf('  → gammaL = %.2f\n', gammaL);
            end
        case 'd'
            val = str2double(cmd(2:end));
            if ~isnan(val) && val > 0
                D0 = round(val);
                fprintf('  → D0 = %d\n', D0);
            end
        case 'c'
            val = str2double(cmd(2:end));
            if ~isnan(val) && val > 0
                c_val = val;
                fprintf('  → c = %.2f\n', c_val);
            end
        case 'r'
            gammaL = 0.4; gammaH = 2.0; c_val = 1.0; D0 = 40;
            fprintf('  → Reset to defaults\n');
        case 'q'
            running = false;
        otherwise
            fprintf('  Unknown command. Use h/l/d/c/r/q\n');
    end
end

%% ---- Cleanup -------------------------------------------------------------
clear cam;
close all;
fprintf('\nTuner stopped. Webcam released.\n');
