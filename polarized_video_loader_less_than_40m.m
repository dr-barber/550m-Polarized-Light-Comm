%% Polarized Video Analysis
% D.E. Barber, Naval Postgraduate School, 3 Feb 2023

close all;
clear;


%% Parameters to Enter

% names
video_name='40m.mp4';    % file name
plot1title='Y Mean for Selected Region of Interest at 40 m';

% cut off thresholds for pulse detection
high_thresh=0.6;
lower_thresh=0.4;

% transmitted signal
pre = "10101010101010101010101010101011";
msg = "0100011101101111010011100110000101110110011110010010111001" + ...
  "0000100110010101100001011101000100000101110010011011010111100100101110";
frame_combined = append(pre,msg);
frame = num2str(frame_combined)-'0';

%% Import video
video = VideoReader(video_name);

%% Select Region of Interest (ROI)
figure 
img = readFrame(video);
imshow(img), title('Draw Rectangle Around Area to Analysis') 
roi=drawrectangle();                        % get ROI from mouse clicks                                         
xMin1= roi.Position(2); xMax1=xMin1+roi.Position(4);   % x min + width
yMin1= roi.Position(1); yMax1=yMin1+roi.Position(3);   % y min + height
close

%% Read video and calculate luminnance values, Y, within ROI
% This pre-processes the video into an array for signal extract/comparison
tic;

k = 1;
% pull RGB values by frame
while hasFrame(video)
    img = readFrame(video);
    Y(:,:,k) = rgb2gray(img(:,:,:));
    k = k+1;  
end

[m,n,p] = size(Y);

% mean lum value of ROI in each frame
for i = 1:p
    Y_mean(i) = mean(Y(xMin1:xMax1,yMin1:yMax1,i),'all');
end

Y_rescaled=rescale(Y_mean);
%{
figure;
plot(Y_rescaled,'b','LineWidth',1.5)
hold on
title(plot1title)
%}


%% Approximate and plot the transmitted signal
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

plot(frame_expanded,'r--')
hold off
%}

%% Clunky bit compare - about 30% BER just struggling with alignment
% Compares whether signal energy is binary high/low vs expanded signal
% With  imprecise transmit timing and fudged signal puncturing, not great

%{
direct_energy_compare = zeros(1,length(frame_expanded)-delay_offset);

for i=2:4:length(frame_expanded)-delay_offset
    if frame_expanded(i) == round(Y_rescaled(i))
        direct_energy_compare(i) = 0;
    else
        direct_energy_compare(i) = 1;
    end
end

figure;
stem(direct_energy_compare)
title('Sample Delta from Scaled and Shifted Bit Stream')

ber_direct_comp = sum(direct_energy_compare)/160
%}

%% Find pulse timings and compare to build received string from pulse width
% Might go back to this as a ref:
% https://stackoverflow.com/questions/47183496/how-to-extract-rising-edge-index-pulsewidth-matlab

[w,initcross,finalcross,midlev] = pulsewidth(Y_rescaled,60,...
    'StateLevels',[lower_thresh high_thresh]);
figure;
movegui('northwest');
pulsewidth(Y_rescaled, 1:16.666667:length(Y_rescaled)/60,...
    'StateLevels',[lower_thresh high_thresh]);



[s,initcross_s,finalcross_s,nextcross]=pulsesep(Y_rescaled,...
    1:16.666667:length(Y_rescaled)/60, 'StateLevels',[lower_thresh high_thresh]);
figure;
movegui('west');
pulsesep(Y_rescaled, 1:16.666667:length(Y_rescaled)/60,...
    'StateLevels',[lower_thresh high_thresh]);


figure;
movegui('southwest');
subplot(1,2,1)
histogram(w,10); title('Histogram of Pulse Widths')
subplot(1,2,2)
histogram(s); title('Histogram of Pulse Seperations')

recovered=[1 0];

for i=1:length(s)
    if w(i) < 0.13
        recovered=[recovered , 1];
    elseif w(i) < 0.17
        recovered=[recovered , 1 1];
    elseif w(i) < 0.224
        recovered=[recovered , 1 1 1];
    else
        recovered=[recovered , 1 1 1 1];
    end

    if s(i) < 6
        recovered=[recovered , 0];
    elseif s(i) < 9
        recovered=[recovered , 0 0];
    elseif s(i) <15
        recovered=[recovered , 0 0 0];
    elseif s(i) < 18
        recovered=[recovered , 0 0 0 0];
    else
        recovered=[recovered , 0 0 0 0 0];
    end
end

recovered=[recovered , 1 1 1 0];




%% Comparing nominal frame vs recovered
figure
stem(-frame)
hold on
stem([recovered],'r')






%% The End
toc;
