%% Polarized Video Analysis
% D.E. Barber, Naval Postgraduate School, 7 Feb 2023
% After the outliers!
close all;
clear;

%% Parameters to Enter

% select video file
video_name='200m_-24eV (12).mp4';      % file name
print_suffix=" at 200 m";

% cleaning constants
preamble_align = [1 0 ];    % Align preamble if first pulse missed


% Cut off thresholds for pulse detection
% This is how much above/below 0.5 makes a flip from 0 to 1 or vice versa
% If too wide, pulses are missed, no downside yet to being narrow
high_cut = 0.55;
low_cut = 0.49;

% Transmitted signal (this shouldn't change for our tests, might in future)
pre = "10101010101010101010101010101011";
msg = "0100011101101111010011100110000101110110011110010010111001" + ...
  "0000100110010101100001011101000100000101110010011011010111100100101110";
frame_combined = append(pre,msg);
frame = num2str(frame_combined)-'0';
% Tx rate was 15 FPS in Python code, camera set to 60 FPS, so 4 samples/bit
sample_rate = 60/15;

%% Import video
video = VideoReader(video_name);

%% Select Region of Interest (ROI)
% cast(value,type) isn't really necessary, but it preempts a lot of run
% time warnings about possible non-integers as array indexes

figure 
img = readFrame(video);
imshow(img), title('Draw Rectangle Around Area to Analysis') 
roi=drawrectangle();        % Get ROI by dragging a rectangle with mouse                                         
xMin1=cast(roi.Position(2),'int16');
xMax1=cast(xMin1+roi.Position(4),'int16');   % x min + width
yMin1=cast(roi.Position(1),'int16'); 
yMax1=cast(yMin1+roi.Position(3),'int16');   % y min + height
close

%% Read video and calculate and condition luminance values, Y, within ROI
% This pre-processes the video into an array for signal extraction
% and comparison based on luminance only
tic;

k = 1;
% Pull RGB values by frame
while hasFrame(video)
    img = readFrame(video);
    Y(:,:,k) = rgb2gray(img(:,:,:));
    k = k+1;  
end

[m,n,p] = size(Y);  % m and n aren't really needed since we're using ROI

% Mean luminance value of ROI in each frame
for i = 1:p
    Y_mean(i) = mean(Y(xMin1:xMax1,yMin1:yMax1,i),'all');
end

% May find a tighter running average removal method but detrend removes 
% any DC slope and is working for now
% **** changing detrend polynomial fit may help sometimes
Y_detrend = detrend(Y_mean(16:600));

% Finds first big discontinuity, which should be start of preamble
start_offset = findchangepts(Y_detrend);

Y_detrend = detrend(Y_mean(start_offset:start_offset+640));

% Rescales all amplitudes between 0 and 1
% Downselecting to a window slightly longer than the frame based on the 
% preamble start location found above
%Y_rescaled=rescale(Y_detrend((max(1,start_offset-16) : ...
%    min(length(Y_detrend),start_offset+sample_rate*length(frame)+16))));

% **** hand selecting on places findchangepts erred
Y_rescaled=rescale(Y_detrend);

figure ('DefaultAxesFontSize',14);
plot(Y_rescaled)
title("Normalized Luminance Value in ROI " + print_suffix)
xlabel("Frame")
ylabel("Normalized Luminance in ROI")

%% Scale and plot the transmitted signal against the received signal
% Tx rate was 15 FPS in Python code, camera set to 60 FPS, so 4 samples/bit
% Measured count is closer to 3.9, so puncturing pattern to shrink

%{
frame_expanded = [];       % align start position              
for i=1:length(frame)      % expand bit string
    if frame(i)==1
        frame_expanded = [frame_expanded, 1 1 1 1 ];   
    else
        frame_expanded = [frame_expanded, 0 0 0 0 ];
    end           
end

indices = 32:48:640;       % puncture to fit closer to 3.9 samples/bit vs 4
frame_expanded(indices) = [];
length_scaled = length(frame_expanded);

% use correlation match in finddelay to offset bit pattern for overlay
%delay_offset = finddelay (frame_expanded , Y_mean);

% alternate approach just using first energy spike
delay_offset = findchangepts(Y_mean);

frame_expanded = [ zeros(1,delay_offset) , frame_expanded];

figure;
plot(Y_rescaled,'b','LineWidth',1.5)
hold on
title(plot1title)

plot(frame_expanded,'r--')
hold off
%}


%% Find pulse timings of the received signal
% Pulls pulse width and spacing using MATLAB functions
% Figure sections (second commented out) useful for troubleshooting

pulse_levels = statelevels(Y_rescaled)

% Find pulse widths (w)

[w,initcross,finalcross,midlev] = pulsewidth(Y_rescaled,60,...
    'StateLevels',[low_cut high_cut]);
figure;
movegui('northwest');
pulsewidth(Y_rescaled, 1:16.666667:length(Y_rescaled)/60,...
    'StateLevels',[low_cut high_cut]);

% Find pulse spacing (s)

[s,initcross_s,finalcross_s,nextcross]=pulsesep(Y_rescaled,...
    1:16.666667:length(Y_rescaled)/60, 'StateLevels',[low_cut high_cut]);
%{
figure;
movegui('west');
pulsesep(Y_rescaled, 1:16.666667:length(Y_rescaled)/60,...
    'StateLevels',[low_cut high_cut]);
%}

%% Gather statistics on pulse timings to set pulse width thresholds

% Histogram of run length counts of transmitted signal, just hardcoded 
% in this file since Tx file doesn't change
%{
mark_num_count = [3 7 8 32]; % for run length 4, 3, 2,and 1 respectively
space_num_count = [1 3 2 12 32]; % for 5, 4, 3, 2, and 1 respectively
%}

% Since we know the statistics of run lengths from the transmitted signal
% above, we sort the pulse intervals to set the bin sizes for how to 
% reconstruct the signal based. Although there is a lot of jitter in our
% transmitter from Python, LCD rolling updates, and timing mismatch on
% between the transmitter and receiver, we can assume the longest pulses
% are the longest runs of ones and the longest lows are the longest runs of
% zeros. Even though ones (and runs of ones) vary in duration from zeros
% (and runs of zeros), using the known statistics of the transmitted signal
% we can reconstruct the signal at the receiver correctly.
w_sorted = sort(w,'descend');
s_sorted = sort(s,'descend');


% Optional plots of the histograms to troubleshoot pulse distributions
%{
figure;
movegui('southwest');
subplot(1,2,1)
histogram(w); title('Histogram of Pulse Widths')
subplot(1,2,2)
histogram(s); title('Histogram of Pulse Seperations')
%}

%% Rebuild received signal based on pulse durations
recovered=preamble_align;

for i=1:length(s)
    if w(i) < w_sorted(18)
        recovered=[recovered , 1];
    elseif w(i) < w_sorted(10)
        recovered=[recovered , 1 1];
    elseif w(i) < w_sorted(3)
        recovered=[recovered , 1 1 1];
    else
        recovered=[recovered , 1 1 1 1];
    end

    if s(i) < s_sorted(18)
        recovered=[recovered , 0];
    elseif s(i) < s_sorted(6)
        recovered=[recovered , 0 0];
    elseif s(i) < s_sorted(4)
        recovered=[recovered , 0 0 0];
    elseif s(i) < s_sorted(1)
        recovered=[recovered , 0 0 0 0];
    else
        recovered=[recovered , 0 0 0 0 0];
    end
end

recovered=[recovered , 1 1 1 0];

%% Comparing transmitted bits vs recovered bits on stem plots
figure
movegui('south')
stem(frame,'filled', 'b--')
hold on
stem(0.9.*recovered,'r','LineWidth',1.5)
title("Transmitted Bits with Recovered Bits Overlaid" + print_suffix)

error_count=0;
for i=1:min(length(frame),length(recovered))
    if frame(i) ~= recovered(i)
        error_count = error_count +1;
    end
end

%% The End
% Write some output to the command window on status of operation
disp(100*(error_count/length(frame)) +"% error"+print_suffix+".")
if error_count > 0
    disp("Check pulse width plot for any pulses detection errors.")
end

toc;