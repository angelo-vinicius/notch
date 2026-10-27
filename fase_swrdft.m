function F = fase_swrdft(x, Fs, f0)
% FASE_SWRDFT
%
% Frequencia e fase instantanea da fundamental, amostra a amostra, a
% partir da SWRDFT (SWRDFT.m, harmonico h = 1).
%
%   F = fase_swrdft(x, Fs, f0)
%
%   x   : sinal de tensao
%   Fs  : taxa de amostragem [Hz]
%   f0  : frequencia NOMINAL [Hz] -- define o tamanho da janela
%
%   F.f       frequencia estimada a cada amostra [Hz]
%   F.theta   fase instantanea da fundamental a cada amostra [rad]
%   F.valido  amostras em que F.f e F.theta ja sao validos
%   F.Nppc    tamanho da janela [amostras]
%
% COMO FUNCIONA
%
% 1. Janela.  A SWRDFT usa uma janela de Nppc = round(Fs/f0) amostras, um
%    ciclo nominal.  A 62,5 kS/s e 60 Hz um ciclo tem 1041,67 amostras;
%    a janela de 1042 cobre 1,0003 ciclo.  Isso nao prejudica a medicao de
%    frequencia e fase (ver item 2).
%
% 2. Frequencia.  Pela variacao da fase ao longo de exatamente uma janela:
%        f(i) = Fs/Nppc + [phi(i) - phi(i-Nppc)] * Fs/(2*pi*Nppc)
%    Tomar a diferenca sobre uma janela inteira cancela a oscilacao de
%    vazamento, que se repete a cada meio ciclo.  Os entalhes deslocam a
%    fase da fundamental de um valor CONSTANTE (cerca de -1 grau), que
%    some na diferenca.
%
% 3. Fase instantanea.  A fase que a SWRDFT entrega descreve o ultimo ciclo
%    inteiro, centrado meio ciclo antes da amostra atual.  Com a rede em
%    60 Hz isso nao importa; fora disso a fase muda durante esse meio
%    ciclo, e e preciso adianta-la:
%        theta(i) = w0*i + phi(i) + (w_estimada - w0)*(Nppc-1)/2
%    Sem essa correcao, o erro e de cerca de 3 graus por hertz de desvio.
%
% 4. Validade.  A frequencia exige duas janelas cheias: uma para a SWRDFT
%    encher, outra para a diferenca de fase.  Antes disso, F.valido = false.

Nppc = round(Fs/f0);
w0   = 2*pi/Nppc;

[~, Ph] = SWRDFT(x, f0, Nppc, 1);
ph = unwrap(Ph(:, 2));                       % coluna 2 = harmonico 1

n = numel(ph);
f = nan(n, 1);
f(Nppc+1:end) = Fs/Nppc + (ph(Nppc+1:end) - ph(1:end-Nppc))*Fs/(2*pi*Nppc);
f(1:min(n, 2*Nppc)) = NaN;                   % so vale depois de duas janelas

wEst  = 2*pi*f/Fs;
theta = w0*(1:n)' + ph + (wEst - w0)*(Nppc - 1)/2;

F = struct('f', f, 'theta', theta, 'valido', ~isnan(f), 'Nppc', Nppc);
end
