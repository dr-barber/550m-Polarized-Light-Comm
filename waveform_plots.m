close all;

Y_rescaled_20=readmatrix('20m_Y_rescaled.csv');
Y_rescaled_550=readmatrix('550m_Y_rescaled.csv');


%% SNR Plot (Figure 6)
figure ('DefaultAxesFontSize',14);
subplot(1,2,1)
plot(Y_rescaled_20)
xlabel({"Frame";"(a)"})
xlim([0 640])
ylabel("Normalized Luminance in ROI")
ylim([-0.05 1.05])
set(gca,'FontWeight','bold',"fontsize",14)

subplot(1,2,2)
plot(Y_rescaled_550)
xlabel({"Frame";"(b)"})
xlim([0 640])
ylim([-0.05 1.05])
set(gca,'FontWeight','bold')


%% SNR Plot (Figure 7)
figure
range = [ 5 10 20 40 80 120 200 220 260 550];
SNR_dB = [39.46801658	31.66119321	35.85433888	37.12334144	31.56533072	28.86833689	23.30096669	18.63753425	18.97507366	8.957585522];
SNR_dB_err =[5.485869426	3.484862878	7.505041866	4.556970132	9.425133014	2.690428183	4.114189205	6.405216908	4.69930417	1.97202891]
errorbar(range, SNR_dB,SNR_dB_err,'--','Linewidth', 2)
xlabel('Range (m)'); xlim([0 560])
xticks([0 50 100 150 200 250 300 350 400 450 500 550])
ylabel('SNR (dB)'); ylim([0 50])
set(gca,'FontWeight','bold','FontSize',14)