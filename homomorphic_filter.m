function output = homomorphic_filter(imgD, gammaL, gammaH, c, D0)
% HOMOMORPHIC_FILTER  Homomorphic filter implemented from scratch
%
%   output = homomorphic_filter(imgD, gammaL, gammaH, c, D0)
%
%   Image Formation Model:
%     An image f(x,y) is formed as:
%       f(x,y) = i(x,y) * r(x,y)
%
%     where:
%       i(x,y) = illumination component (slow-varying, low-frequency)
%                Determined by the light source. Range: [0, inf)
%       r(x,y) = reflectance component  (fast-varying, high-frequency)
%                Determined by surface properties. Range: [0, 1]
%
%   Problem:
%     Since i and r are MULTIPLICATIVE, they cannot be separated by
%     standard linear filtering in the spatial or frequency domain.
%
%   Solution — Homomorphic Filtering:
%     Step 1: z(x,y) = ln[f(x,y)] = ln[i(x,y)] + ln[r(x,y)]
%             The LOG converts multiplication to ADDITION.
%
%     Step 2: Z(u,v) = DFT{z(x,y)} = FI(u,v) + FR(u,v)
%             Now illumination and reflectance are additive in
%             the frequency domain.
%
%     Step 3: Apply a HIGH-EMPHASIS filter H(u,v):
%             S(u,v) = H(u,v) * Z(u,v)
%
%             H(u,v) = (gammaH - gammaL) * [1 - exp(-c * D²/D0²)] + gammaL
%
%             - gammaL < 1 : attenuates low frequencies (illumination)
%                            → compresses dynamic range
%             - gammaH > 1 : amplifies high frequencies (reflectance)
%                            → enhances edges, details, contrast
%
%     Step 4: s(x,y) = IDFT{S(u,v)}
%
%     Step 5: g(x,y) = exp[s(x,y)]
%             The EXP reverses the initial LOG transform.
%
%   Result:
%     The output image has:
%       - Reduced illumination variation (more uniform brightness)
%       - Enhanced reflectance details (sharper edges, more contrast)
%     This is especially useful for images with uneven lighting,
%     shadows, or high dynamic range scenes like faces, indoor scenes,
%     and satellite images.
%
%   Filter Parameters:
%     gammaL  - Low-frequency gain  (< 1, typical: 0.3 – 0.5)
%     gammaH  - High-frequency gain (> 1, typical: 1.5 – 2.5)
%     c       - Controls sharpness of H transition (typical: 1.0)
%     D0      - Cutoff frequency in pixels (typical: 20 – 60)
%
%   Inputs:
%     imgD   - Grayscale image, double, values in [0,1]
%     gammaL - Low-frequency gain
%     gammaH - High-frequency gain
%     c      - Transition sharpness
%     D0     - Cutoff frequency (pixels)
%
%   Output:
%     output - Enhanced image, double, values in [0,1]

[M, N] = size(imgD);

% ---- Step 1: Log Transform ------------------------------------------------
% Add epsilon to prevent log(0) = -inf
epsilon = 1e-6;
logImg = log(imgD + epsilon);

% ---- Step 2: 2D DFT + shift DC to centre ----------------------------------
F = fftshift(fft2(logImg));

% ---- Step 3: Build Homomorphic Filter H(u,v) ------------------------------
%   H(u,v) = (gammaH - gammaL) * (1 - exp(-c * D²/D0²)) + gammaL
%
%   At D = 0 (DC):   H = gammaL  (attenuate illumination)
%   At D >> D0:       H → gammaH (amplify reflectance)

[u, v] = meshgrid(1:N, 1:M);
centerU = floor(N/2) + 1;
centerV = floor(M/2) + 1;
D2 = (u - centerU).^2 + (v - centerV).^2;   % D²(u,v)

H = (gammaH - gammaL) .* (1 - exp(-c .* D2 ./ (D0^2))) + gammaL;

% ---- Step 4: Apply filter in frequency domain -----------------------------
G = F .* H;

% ---- Step 5: Inverse DFT + Exponential -----------------------------------
filtered = real(ifft2(ifftshift(G)));
output   = exp(filtered) - epsilon;

% ---- Normalize to [0,1] using percentile clipping -------------------------
%   Min-max normalization fails when exp() produces extreme outlier peaks
%   (especially at high gammaH). A single extreme pixel forces all other
%   pixels to near-zero. Percentile-based clipping removes these outliers
%   before normalizing, producing a correctly enhanced image.
pLow  = prctile(output(:), 1);    % 1st percentile
pHigh = prctile(output(:), 99);   % 99th percentile
if pHigh > pLow
    output = (output - pLow) / (pHigh - pLow);
    output = max(0, min(1, output));   % clamp to [0,1]
else
    output = zeros(M, N);
end

end
