% =========================================================================
%  LIVE HOMOMORPHIC FILTERING
%
%  Captures live webcam frames, converts to grayscale, and applies
%  homomorphic filtering in real time. Displays all six intermediate
%  stages of the pipeline simultaneously:
%
%      ┌──────────────┬──────────────┬──────────────┐
%      │   Original   │   Log(f)     │  Filter H    │
%      ├──────────────┼──────────────┼──────────────┤
%      │   DFT of     │  Filtered    │  ENHANCED    │
%      │   log(f)     │  Spectrum    │  OUTPUT      │
%      └──────────────┴──────────────┴──────────────┘
%
%  A separate figure shows H(u,v) as a 3D surface and cross-section.
%
%  Requirements:
%    - MATLAB R2020b or later
%    - Image Processing Toolbox
%    - MATLAB Support Package for USB Webcams
%
%  Controls:
%    - Close the figure window to stop
%    - Ctrl+C in the Command Window to force stop
%
%  Run:
%    >> live_homomorphic
% =========================================================================

clear; close all; clc;

%% ---- CONFIGURATION ------------------------------------------------------
cfg.gammaL   = 0.4;     % Low-frequency gain  (illumination suppression)
cfg.gammaH   = 2.0;     % High-frequency gain (reflectance enhancement)
cfg.c        = 1.0;     % Transition sharpness
cfg.D0       = 40;      % Cutoff frequency (pixels)
cfg.scale    = 0.5;     % Frame resize factor (for speed)

fprintf('╔══════════════════════════════════════════════════╗\n');
fprintf('║          LIVE HOMOMORPHIC FILTERING             ║\n');
fprintf('╠══════════════════════════════════════════════════╣\n');
fprintf('║  γ_L  = %.2f  (illumination attenuation)       ║\n', cfg.gammaL);
fprintf('║  γ_H  = %.2f  (reflectance amplification)      ║\n', cfg.gammaH);
fprintf('║  c    = %.2f  (transition sharpness)            ║\n', cfg.c);
fprintf('║  D0   = %d px (cutoff frequency)               ║\n', cfg.D0);
fprintf('║                                                  ║\n');
fprintf('║  Close the figure window to stop.                ║\n');
fprintf('╚══════════════════════════════════════════════════╝\n\n');

%% ---- INITIALIZE WEBCAM --------------------------------------------------
try
    cam = webcam(1);
    cam.Resolution = cam.AvailableResolutions{1};
    fprintf('✓ Webcam: %s  |  Resolution: %s\n\n', cam.Name, cam.Resolution);
catch ME
    error(['Could not open webcam: ' ME.message ...
           '\nMake sure a webcam is connected and not in use by another app.']);
end

%% ---- GRAB ONE FRAME TO GET IMAGE SIZE -----------------------------------
testFrame = snapshot(cam);
testFrame = imresize(testFrame, cfg.scale);
grayTest  = im2double(rgb2gray(testFrame));
[M, N] = size(grayTest);
fprintf('Processing frame size: %d × %d\n', M, N);

%% ---- PRE-COMPUTE FILTER H(u,v) -----------------------------------------
% The filter only depends on image size and parameters — compute once
[u, v] = meshgrid(1:N, 1:M);
centerU = floor(N/2) + 1;
centerV = floor(M/2) + 1;
D2 = (u - centerU).^2 + (v - centerV).^2;
D  = sqrt(D2);

H = (cfg.gammaH - cfg.gammaL) .* (1 - exp(-cfg.c .* D2 ./ (cfg.D0^2))) + cfg.gammaL;

%% ---- SHOW FILTER CHARACTERISTICS (separate figure) ----------------------
figH = figure('Name', 'Homomorphic Filter H(u,v)', ...
              'Color', 'white', 'Position', [50 50 900 400]);

% 3D surface
subplot(1,2,1);
surf(H, 'EdgeColor', 'none');
colormap(subplot(1,2,1), parula);
colorbar;
title(sprintf('H(u,v) Surface\n\\gamma_L=%.1f  \\gamma_H=%.1f  D_0=%d', ...
      cfg.gammaL, cfg.gammaH, cfg.D0), 'FontSize', 12, 'FontWeight', 'bold');
xlabel('u'); ylabel('v'); zlabel('H(u,v)');
view(-30, 45);
set(gca, 'FontSize', 10);

% Cross-section through centre
subplot(1,2,2);
midRow = centerV;
Dslice = D(midRow, :);
Hslice = H(midRow, :);
plot(Dslice - min(Dslice(:)), Hslice, '-', 'Color', [0.2 0.4 0.9], 'LineWidth', 2.5);
hold on;
yline(cfg.gammaL, '--r', sprintf('\\gamma_L = %.1f', cfg.gammaL), ...
      'LineWidth', 1.5, 'FontSize', 10, 'LabelHorizontalAlignment', 'left');
yline(cfg.gammaH, '--', 'Color', [0 0.6 0.3], ...
      'Label', sprintf('\\gamma_H = %.1f', cfg.gammaH), ...
      'LineWidth', 1.5, 'FontSize', 10, 'LabelHorizontalAlignment', 'left');
xline(cfg.D0, ':', sprintf('D_0 = %d', cfg.D0), 'LineWidth', 1.5, 'FontSize', 10);
hold off;
xlabel('Distance from DC (pixels)', 'FontSize', 12);
ylabel('H(D)', 'FontSize', 12);
title('Filter Cross-Section', 'FontSize', 12, 'FontWeight', 'bold');
grid on; set(gca, 'FontSize', 10);
ylim([0, cfg.gammaH + 0.3]);

drawnow;

%% ---- CREATE LIVE DISPLAY FIGURE -----------------------------------------
figLive = figure('Name', 'Live Homomorphic Filtering', ...
                 'NumberTitle', 'off', ...
                 'Color', [0.05 0.05 0.08], ...
                 'Position', [50 480 1400 550]);

% 6 panels: 2 rows × 3 columns
panelTitles = {'1. Original f(x,y)', ...
               '2. Log Domain: ln[f(x,y)]', ...
               '3. Filter H(u,v)', ...
               '4. Spectrum |F\{ln[f]\}|', ...
               '5. Filtered Spectrum', ...
               '6. Enhanced Output g(x,y)'};

hAx  = gobjects(1, 6);
hImg = gobjects(1, 6);

for k = 1:6
    hAx(k) = subplot(2, 3, k, 'Parent', figLive);
    title(hAx(k), panelTitles{k}, 'Color', 'white', 'FontSize', 10, 'FontWeight', 'bold');
    set(hAx(k), 'XTick', [], 'YTick', [], 'Box', 'on', ...
                 'XColor', [0.3 0.3 0.4], 'YColor', [0.3 0.3 0.4], ...
                 'Color', [0.08 0.08 0.12]);
end

% Initialize with dummy images
dummyGray = zeros(M, N, 3, 'uint8');
for k = 1:6
    axes(hAx(k)); %#ok<LAXES>
    hImg(k) = imshow(dummyGray);
end

% Metric text on the output panel
hMetric = text(hAx(6), 5, M-10, '', ...
    'Color', [0 1 0.8], 'FontSize', 9, 'FontWeight', 'bold', ...
    'BackgroundColor', [0 0 0 0.6], 'Margin', 3, ...
    'VerticalAlignment', 'bottom');

% Step annotation on each panel
stepColors = {[1 1 1], [1 0.9 0.4], [0.4 0.8 1], [1 0.6 0.4], [0.6 1 0.6], [0 1 0.8]};
for k = 1:6
    text(hAx(k), 5, 5, sprintf('Step %d', k), ...
         'Color', stepColors{k}, 'FontSize', 8, 'FontWeight', 'bold', ...
         'BackgroundColor', [0 0 0 0.5], 'Margin', 2, ...
         'VerticalAlignment', 'top');
end

drawnow;

%% ---- PRE-COMPUTE DISPLAY VERSION OF H ----------------------------------
% Normalize H to [0,1] for display
Hdisp = (H - min(H(:))) / (max(H(:)) - min(H(:)));
HdispRGB = repmat(uint8(Hdisp * 255), [1 1 3]);
% Apply a colormap for better visualization
HdispRGB = ind2rgb(uint8(Hdisp * 255), parula(256));
HdispRGB = uint8(HdispRGB * 255);

%% ---- MAIN LOOP ----------------------------------------------------------
frameCount = 0;
tic;

fprintf('\n▶ Live filtering started. Close figure to stop.\n');

while ishandle(figLive)
    frameCount = frameCount + 1;

    %-- Capture and convert ------------------------------------------------
    rawFrame = snapshot(cam);
    rawFrame = imresize(rawFrame, cfg.scale);
    grayD    = im2double(rgb2gray(rawFrame));

    %-- Step 1: Original image  f(x,y) ------------------------------------
    origRGB = repmat(uint8(grayD * 255), [1 1 3]);

    %-- Step 2: Log transform  z = ln[f + ε] ------------------------------
    epsilon = 1e-6;
    logImg  = log(grayD + epsilon);
    % Normalize log image for display
    logDisp = (logImg - min(logImg(:))) / (max(logImg(:)) - min(logImg(:)) + eps);
    logRGB  = repmat(uint8(logDisp * 255), [1 1 3]);

    %-- Step 3: Filter H(u,v) — already pre-computed (static) -------------

    %-- Step 4: DFT of log image  F{ln[f]} --------------------------------
    F = fftshift(fft2(logImg));
    specMag = log(abs(F) + 1);
    specDisp = specMag / max(specMag(:));
    specRGB = repmat(uint8(specDisp * 255), [1 1 3]);

    %-- Step 5: Filtered spectrum  S = H * F -------------------------------
    G = F .* H;
    filtSpecMag = log(abs(G) + 1);
    filtSpecDisp = filtSpecMag / max(filtSpecMag(:));
    filtSpecRGB = repmat(uint8(filtSpecDisp * 255), [1 1 3]);

    %-- Step 6: IDFT + Exp → Enhanced output  g(x,y) ----------------------
    filtered = real(ifft2(ifftshift(G)));
    enhanced = exp(filtered) - epsilon;
    % Normalize to [0,1]
    eMin = min(enhanced(:));
    eMax = max(enhanced(:));
    if eMax > eMin
        enhanced = (enhanced - eMin) / (eMax - eMin);
    end
    enhRGB = repmat(uint8(enhanced * 255), [1 1 3]);

    %-- Compute quality metrics (enhanced vs original) ---------------------
    mse_val = mean((grayD(:) - enhanced(:)).^2);
    if mse_val < 1e-14
        psnr_val = Inf;
    else
        psnr_val = 10 * log10(1.0 / mse_val);
    end

    % Contrast improvement ratio
    contrastOrig = std(grayD(:));
    contrastEnh  = std(enhanced(:));
    cir = contrastEnh / max(contrastOrig, eps);

    metricText = sprintf('PSNR: %.1f dB\nContrast Ratio: %.2f×', psnr_val, cir);

    %-- Update display -----------------------------------------------------
    set(hImg(1), 'CData', origRGB);
    set(hImg(2), 'CData', logRGB);
    set(hImg(3), 'CData', HdispRGB);
    set(hImg(4), 'CData', specRGB);
    set(hImg(5), 'CData', filtSpecRGB);
    set(hImg(6), 'CData', enhRGB);

    set(hMetric, 'String', metricText);

    % FPS in title
    elapsed = toc;
    fps = frameCount / elapsed;
    set(figLive, 'Name', sprintf('Live Homomorphic Filtering  |  FPS: %.1f  |  Frame: %d', fps, frameCount));

    drawnow limitrate;
end

%% ---- CLEANUP ------------------------------------------------------------
clear cam;
fprintf('\n■ Stopped. Webcam released. %d frames processed.\n', frameCount);
