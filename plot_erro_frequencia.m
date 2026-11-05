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

% V pode ser um VETOR de structs, um por nivel de ruido (campo snr): uma
% curva por nivel, com as cores dos graficos de validacao (45 dB azul,
% 55 dB vermelho, 65 dB laranja).

if nargin < 1
    error('plot_erro_frequencia:semDados', ['plot_erro_frequencia desenha dados calculados pelo teste 4 e precisa\n' ...
          'recebe-los; nao se roda sozinha.  Para gerar os graficos, rode\n' ...
          'teste_4_fase_swrdft.  Para redesenha-los a partir do resultado ja\n' ...
          'gravado, rode o teste 4 com soRedesenhar = true.']);
end

nV = numel(V);
figure('Name', 'Teste 4 - erro RMS da frequencia estimada pela SWRDFT [%]', 'Color', 'w');
hold on;
h = zeros(1, nV);  rot = cell(1, nV);  rMinT = inf;  rMaxT = 0;
for k = 1:nV
    f    = V(k).freq(:)';
    rPct = 100*V(k).fRms(:)'./f;      % erro RMS [%]
    c    = cor_snr(V(k));
    h(k) = plot(f, rPct, '-o', 'Color', c, 'LineWidth', 1.8, ...
                'MarkerSize', 4, 'MarkerFaceColor', c);
    rot{k} = rotulo_snr(V(k));
    [rm, im] = min(rPct);
    if rm < rMinT, rMinT = rm; fMinT = f(im); end
    rMaxT = max(rMaxT, max(rPct));
end
xlim([V(1).freq(1) V(1).freq(end)]);
ylim([0 1.1*rMaxT]);
grid on;  box on;
xlabel('frequencia real da rede [Hz]');
ylabel('erro RMS da frequencia estimada [%]');
title(sprintf('Erro RMS da frequencia (SWRDFT): %.4f %% em %g Hz a %.3f %%', ...
              rMinT, fMinT, rMaxT));
if nV > 1 || isfield(V, 'snr')
    legend(h, rot, 'Location', 'north');
end
end

function c = cor_snr(Vk)
% cor de cada nivel de ruido (a mesma dos graficos de validacao)
c = [0.15 0.35 0.75];
if isfield(Vk, 'snr')
    switch Vk.snr
        case 45, c = [0.216 0.541 0.867];
        case 55, c = [0.886 0.294 0.290];
        case 65, c = [0.937 0.624 0.153];
    end
end
end

function r = rotulo_snr(Vk)
if isfield(Vk, 'snr'), r = sprintf('%g dB', Vk.snr); else, r = 'erro RMS'; end
end
