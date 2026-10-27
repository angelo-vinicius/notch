function plot_erro_frequencia(V)
% PLOT_ERRO_FREQUENCIA
%
% Erro RMS da frequencia estimada pela SWRDFT em funcao da frequencia real
% da rede, EM PORCENTAGEM da frequencia real.
%
%   plot_erro_frequencia(V)
%
%   V   struct com um valor por frequencia testada:
%         freq  frequencia real da rede [Hz]
%         fRms  raiz do erro medio quadratico da frequencia estimada [Hz]
%
% ERRO RMS
%   Para cada frequencia testada, a SWRDFT estima a frequencia a cada
%   amostra.  O erro RMS e a raiz da media dos quadrados dos erros:
%       erro RMS = sqrt( media( (f_estimada - f_real)^2 ) )
%   Junta o vies (erro medio) e a oscilacao de amostra para amostra:
%       RMS^2 = (erro medio)^2 + (oscilacao)^2
%
% PORCENTAGEM
%   O erro RMS de cada ponto e dividido pela frequencia real daquele ponto:
%       erro RMS [%] = 100 * erro RMS [Hz] / f_real [Hz]
%   Exemplo: 0,29 Hz com a rede em 55 Hz = 0,53 %.
%
% COMO LER
%   O erro e minimo perto de 60 Hz e cresce com o desvio, porque a janela
%   da SWRDFT tem o tamanho de um ciclo de 60 Hz e fecha cada vez menos um
%   ciclo real (vazamento espectral).  O erro medio (vies), muito menor, e
%   os valores em Hz estao na Tabela 5 do teste 4.
%
% Usa so comandos basicos (plot, figure), para funcionar no MATLAB e no
% Octave.

f    = V.freq(:)';
rPct = 100*V.fRms(:)'./f;          % erro RMS [%]
azul = [0.15 0.35 0.75];
[rMin, iMin] = min(rPct);

figure('Name', 'Teste 4 - erro RMS da frequencia estimada pela SWRDFT [%]', 'Color', 'w');
plot(f, rPct, '-o', 'Color', azul, 'LineWidth', 1.8, ...
     'MarkerSize', 4, 'MarkerFaceColor', azul);
xlim([f(1) f(end)]);
ylim([0 1.1*max(rPct)]);
grid on;
xlabel('frequencia real da rede [Hz]');
ylabel('erro RMS da frequencia estimada [%]');
title(sprintf('Frequencia estimada pela SWRDFT: erro RMS de %.4f %% (em %g Hz) a %.3f %%', ...
              rMin, f(iMin), max(rPct)));
end