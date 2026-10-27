%% TESTE 2 - RUIDO
%
% Segundo degrau da escada de escalabilidade.
%
% PERGUNTA
%   Acrescentando ruido gaussiano ao sinal do teste 1, ate que nivel a
%   cadeia continua detectando e medindo corretamente?  Onde ela quebra, e
%   por que?
%
% METODO
%   O mesmo sinal do teste 1, com ruido de intensidade crescente.  O SNR
%   (relacao sinal-ruido) desce de 60 dB ate 25 dB; cada 20 dB a menos
%   significa ruido 10 vezes maior.  Cada nivel e repetido com 3 sorteios
%   de ruido diferentes, e os resultados sao somados.
%
% RESULTADO ESPERADO
%   Deteccao perfeita ate certo nivel; depois, perda progressiva dos
%   entalhes menores.
%
% ARQUIVOS NECESSARIOS (todos nesta pasta)
%   gerar_sinal_teste.m, notch_analyze.m, notch_detector.m,
%   parear_eventos.m, avaliar_cenario.m, escada_util.m, descrever_sinal.m,
%   fase_swrdft.m, SWRDFT.m (estimativa de frequencia no notch_analyze)

clear; close all; clc;

%% ================= 1. SINAL TESTADO =================
% Mesma ponte de 6 pulsos do teste 1.
Fs       = 62.5e3;
f0       = 60;
nCiclos  = 12;
Vll      = 480;
alphaDeg = 35;
muDeg    = 9;
Ls       = 30e-6;
Lt       = 70e-6;

sinal = {'Modo', 'conversor', 'Fs', Fs, 'f0', f0, 'nCiclos', nCiclos, ...
         'Vll', Vll, 'Grandeza', 'fase-fase', ...
         'alphaDeg', alphaDeg, 'muDeg', muDeg, 'Ls', Ls, 'Lt', Lt, ...
         'Bits', []};

% O que este teste acrescenta: ruido, em varios niveis.
niveisSNR = [60 55 50 45 40 35 30 25];      % [dB]

% Exemplo do sinal num nivel intermediario, so para visualizacao
snrExemplo = 40;
[x, t, truth, meta] = gerar_sinal_teste(sinal{:}, 'SNRdb', snrExemplo, 'Semente', 1);
xRef = gerar_sinal_teste(sinal{:}, 'Semente', 1, 'Ls', 0);
descrever_sinal(x, t, truth, meta, sprintf('com ruido de %g dB', snrExemplo), xRef);

% Quanto ruido cada nivel representa.  O desvio-padrao e medido
% diretamente: mesmo sinal com e sem ruido, mesma semente.
% O detector exige que um entalhe supere um piso de 5 vezes esse desvio,
% para nao confundir ruido com entalhe.
xLimpo = gerar_sinal_teste(sinal{:}, 'Semente', 1);
fprintf('\nNIVEIS DE RUIDO TESTADOS\n');
fprintf('%8s | %12s | %16s\n', 'SNR', 'sigma [V]', 'piso 5*sigma [V]');
for snr = niveisSNR
    xr = gerar_sinal_teste(sinal{:}, 'SNRdb', snr, 'Semente', 1);
    sg = std(xr - xLimpo);
    fprintf('%5g dB | %12.2f | %16.1f\n', snr, sg, 5*sg);
end

%% ================= 2. AVALIACAO =================
sementes = [1 2 3];
crit = escada_util('criterios');

escada_util('cabecalho', 'TESTE 2 - ruido gaussiano');
resultados = struct('snr', {}, 'S', {}, 'veredito', {});
for snr = niveisSNR
    S = avaliar_cenario([sinal {'SNRdb', snr}], sementes);
    v = escada_util('veredito', S, crit);
    escada_util('linha', sprintf('SNR %g dB', snr), S, v);
    resultados(end+1) = struct('snr', snr, 'S', S, 'veredito', v);   %#ok<SAGROW>
end

%% ================= 3. RESULTADO =================
vs = {resultados.veredito};
iOK = find(strcmp(vs, 'OK'), 1, 'last');
iQB = find(strcmp(vs, 'QUEBROU'), 1, 'first');

fprintf('\nRESUMO\n');
if ~isempty(iOK)
    fprintf('  ultimo nivel OK ........... SNR %g dB\n', resultados(iOK).snr);
end
iAT = find(strcmp(vs, 'ATENCAO'));
if ~isempty(iAT)
    fprintf('  niveis em ATENCAO ......... %s dB\n', mat2str([resultados(iAT).snr]));
end
if ~isempty(iQB)
    fprintf('  quebra a partir de ........ SNR %g dB\n', resultados(iQB).snr);
else
    fprintf('  nao quebrou na faixa testada\n');
end

fprintf('\nCOMO LER\n');
fprintf('  verd = entalhes verdadeiros depois do aquecimento (o primeiro ciclo),\n');
fprintf('  somados nas %d sementes.\n', numel(sementes));
fprintf('  ATENCAO sem falsos nem perdidos significa deteccao perfeita com a\n');
fprintf('  profundidade um pouco superestimada: o maior de varios valores com\n');
fprintf('  ruido tende a exagerar.  A area, que e uma soma, quase nao e afetada.\n');
fprintf('  A quebra acontece quando o piso 5*sigma passa a ser comparavel a\n');
fprintf('  profundidade dos entalhes rasos (~70 V) e, depois, dos profundos.\n');

pasta = fileparts(mfilename('fullpath'));
save(fullfile(pasta, 'resultado_teste_2.mat'), 'resultados', 'crit', 'sinal', 'sementes');
fprintf('\nResultado gravado em resultado_teste_2.mat\n');
