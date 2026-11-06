% =========================================================================
%  OFFLINE HOMOMORPHIC FILTER ANALYSIS (No Webcam Required)
%
%  Uses MATLAB's built-in test images to run the homomorphic filtering
%  pipeline and generate publication-quality output figures.
%
%  Run:
%    >> offline_homomorphic
%
%  Outputs:
%    - homomorphic_comparison.png  (before/after + histograms + spectrum)
%    - parameter_sweep.png         (gammaH and gammaL sensitivity sweeps)
%    - filter_3d_surface.png       (H(u,v) 3D surface + cross-section)
% =========================================================================

clear; close all; clc;

fprintf('=== Offline Homomorphic Filter Analysis ===\n\n');

%% ---- Load test image ----------------------------------------------------
try
    img = im2double(rgb2gray(imread('peppers.png')));
    imgName = 'peppers.png';
catch
    img = im2double(imread('cameraman.tif'));
    imgName = 'cameraman.tif';
end
[M, N] = size(img);
fprintf('Test image: %s  (%d × %d)\n\n', imgName, M, N);

%% ---- 1. Standard comparison: Original vs Enhanced -----------------------
fprintf('Step 1: Standard homomorphic filtering...\n');

gammaL = 0.4;  gammaH = 2.0;  c = 1.0;  D0 = 40;

enhanced = homomorphic_filter(img, gammaL, gammaH, c, D0);

fig1 = figure('Name', 'Homomorphic Filter Comparison', ...
              'Color', [0.06 0.06 0.10], 'Position', [50 50 1400 800]);

% Row 1: Images
subplot(2,3,1);
imshow(img); title('Original f(x,y)', 'Color', 'w', 'FontSize', 11, 'FontWeight', 'bold');

subplot(2,3,2);
logDisp = log(img + 1e-6);
logDisp = (logDisp - min(logDisp(:))) / (max(logDisp(:)) - min(logDisp(:)));
imshow(logDisp); title('Log Domain ln[f]', 'Color', [1 0.9 0.4], 'FontSize', 11, 'FontWeight', 'bold');

subplot(2,3,3);
imshow(enhanced); title('Enhanced g(x,y)', 'Color', [0 1 0.8], 'FontSize', 11, 'FontWeight', 'bold');

% Row 2: Histograms and spectra
subplot(2,3,4);
histogram(img(:)*255, 256, 'FaceColor', [0.3 0.5 0.9], 'EdgeColor', 'none');
title('Original Histogram', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('Intensity'); ylabel('Count'); xlim([0 255]); grid on;

subplot(2,3,5);
% Show DFT spectrum
F = fftshift(fft2(log(img + 1e-6)));
specMag = log(abs(F) + 1);
imagesc(specMag / max(specMag(:)));
colormap(subplot(2,3,5), hot);
title('|F\{ln[f]\}| Spectrum', 'FontSize', 11, 'FontWeight', 'bold');
axis image; colorbar;

subplot(2,3,6);
histogram(enhanced(:)*255, 256, 'FaceColor', [0.2 0.9 0.5], 'EdgeColor', 'none');
title('Enhanced Histogram', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('Intensity'); ylabel('Count'); xlim([0 255]); grid on;

sgtitle(sprintf('Homomorphic Filtering:  \\gamma_L=%.1f  \\gamma_H=%.1f  c=%.1f  D_0=%d', ...
        gammaL, gammaH, c, D0), 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'white');

exportgraphics(fig1, 'homomorphic_comparison.png', 'Resolution', 150);
fprintf('  Saved: homomorphic_comparison.png\n');

%% ---- 2. Parameter sweep: gammaH vs gammaL ------------------------------
fprintf('\nStep 2: Parameter sweep...\n');

gammaH_vals = [1.2, 1.5, 2.0, 2.5, 3.0];
gammaL_vals = [0.2, 0.3, 0.4, 0.5, 0.7];

fig2 = figure('Name', 'gammaH Sweep', 'Color', 'white', 'Position', [50 50 1400 600]);

% Row 1: gammaH sweep (gammaL = 0.4 fixed)
for i = 1:5
    subplot(2, 5, i);
    enh_i = homomorphic_filter(img, 0.4, gammaH_vals(i), 1.0, 40);
    imshow(enh_i);
    cir = std(enh_i(:)) / max(std(img(:)), eps);
    title(sprintf('\\gamma_H = %.1f\nCIR = %.2f', gammaH_vals(i), cir), ...
          'FontSize', 10, 'FontWeight', 'bold');
end
annotation(fig2, 'textbox', [0.02 0.75 0.05 0.05], 'String', ...
           '\\gamma_H sweep\n(\\gamma_L=0.4)', 'FontSize', 10, ...
           'EdgeColor', 'none', 'FontWeight', 'bold');

% Row 2: gammaL sweep (gammaH = 2.0 fixed)
for i = 1:5
    subplot(2, 5, 5+i);
    enh_i = homomorphic_filter(img, gammaL_vals(i), 2.0, 1.0, 40);
    imshow(enh_i);
    cir = std(enh_i(:)) / max(std(img(:)), eps);
    title(sprintf('\\gamma_L = %.1f\nCIR = %.2f', gammaL_vals(i), cir), ...
          'FontSize', 10, 'FontWeight', 'bold');
end
annotation(fig2, 'textbox', [0.02 0.25 0.05 0.05], 'String', ...
           '\\gamma_L sweep\n(\\gamma_H=2.0)', 'FontSize', 10, ...
           'EdgeColor', 'none', 'FontWeight', 'bold');

exportgraphics(fig2, 'parameter_sweep.png', 'Resolution', 150);
fprintf('  Saved: parameter_sweep.png\n');

%% ---- 3. Filter 3D surface and cross-sections ----------------------------
fprintf('\nStep 3: Filter characteristics...\n');

[u, v] = meshgrid(1:N, 1:M);
cU = floor(N/2)+1; cV = floor(M/2)+1;
D2 = (u-cU).^2 + (v-cV).^2;
D = sqrt(D2);

H = (gammaH - gammaL) .* (1 - exp(-c .* D2 ./ (D0^2))) + gammaL;

fig3 = figure('Name', 'Filter H(u,v)', 'Color', 'white', 'Position', [100 100 1000 450]);

subplot(1,2,1);
surf(H, 'EdgeColor', 'none');
colormap(subplot(1,2,1), parula);
colorbar;
title('H(u,v) Transfer Function', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('u'); ylabel('v'); zlabel('H');
view(-35, 40);

subplot(1,2,2);
Dline = 0:max(N,M)/2;
Hline = (gammaH - gammaL) .* (1 - exp(-c .* Dline.^2 ./ (D0^2))) + gammaL;
plot(Dline, Hline, '-', 'Color', [0.2 0.4 0.9], 'LineWidth', 2.5);
hold on;
yline(gammaL, '--r', sprintf('\\gamma_L = %.1f (illumination)', gammaL), 'LineWidth', 1.5, 'FontSize', 9);
yline(gammaH, '--', 'Color', [0 0.6 0.2], 'Label', sprintf('\\gamma_H = %.1f (reflectance)', gammaH), 'LineWidth', 1.5, 'FontSize', 9);
xline(D0, ':', sprintf('D_0 = %d', D0), 'LineWidth', 1.5, 'FontSize', 9);
% Mark the half-power point
halfGain = (gammaH + gammaL) / 2;
yline(halfGain, '-.', sprintf('Half gain = %.2f', halfGain), 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
hold off;
xlabel('Distance from DC (pixels)', 'FontSize', 12);
ylabel('H(D)', 'FontSize', 12);
title('Cross-Section through DC', 'FontSize', 12, 'FontWeight', 'bold');
grid on; ylim([0, gammaH + 0.5]);

exportgraphics(fig3, 'filter_3d_surface.png', 'Resolution', 150);
fprintf('  Saved: filter_3d_surface.png\n');

%% ---- Print summary ------------------------------------------------------
fprintf('\n--- Results Summary ---\n');
fprintf('Original image contrast (std): %.4f\n', std(img(:)));
fprintf('Enhanced image contrast (std): %.4f\n', std(enhanced(:)));
fprintf('Contrast Improvement Ratio:    %.2f×\n', std(enhanced(:))/std(img(:)));

mse_val = mean((img(:) - enhanced(:)).^2);
fprintf('MSE:  %.6f\n', mse_val);
fprintf('PSNR: %.2f dB\n', 10*log10(1/mse_val));
fprintf('\n=== Done ===\n');
