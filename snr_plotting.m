%% SNR Plot

range = [ 5 10 20 40 80 120 200 220 260 550];
SNR_lin = [ 111.25 67.36 64.91 51.42 24.72 7.34 9.29 9.33 7.56 4.31];
SNR_dB = [40.9 36.6 36.4 34.2 27.9 17.3 19.4 19.4 17.6 12.7];
log2_SNR_dB = [6.81 6.10 6.04 5.71 4.68 3.06 3.36 3.37 3.10 2.41];

yyaxis left
plot(range, SNR_lin,'b--', 'Linewidth', 1.5)
xlabel('Range (m)');xlim([0 550])
ylabel('SNR (Linear)');ylim([0 120])

yyaxis right
plot(range, SNR_dB,'r','Linewidth', 1.5)
xlabel('Range (m)'); xlim([0 550])
ylabel('SNR (dB)'); ylim([0 41])