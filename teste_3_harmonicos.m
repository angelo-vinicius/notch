%% TESTE 3 - HARMONICOS DE FUNDO
%
% Terceiro degrau da escada de escalabilidade.
%
% PERGUNTA
%   Uma rede real ja e distorcida antes de qualquer entalhe.  Acrescentando
%   harmonicos de fundo ao sinal com ruido, a cadeia continua detectando e
%   medindo corretamente?
%
% METODO
%   O sinal do teste 2 com ruido FIXO de 55 dB -- um nivel que passou com
%   folga no teste 2 --, mais 5a, 7a, 11a e 13a harmonicas, com a distorcao
%   harmonica total (THD) subindo de 0 a 10 %.  Uma instalacao industrial
%   tipica fica entre 3 e 8 %.  Cada nivel e repetido com 3 sorteios de
%   ruido.
%
% POR QUE ISSO ERA UM PROBLEMA
%   A versao original do detector reconstruia a forma de onda durante o
%   entalhe com UMA senoide, e quebrava com apenas 3 % de THD.  A versao
%   atual usa um banco de ressonadores, um por harmonico.  Este teste
%   verifica que isso resolveu.
%
% ARQUIVOS NECESSARIOS (todos nesta pasta)
%   gerar_sinal_teste.m, notch_analyze.m, notch_detector.m,
%   parear_eventos.m, avaliar_cenario.m, escada_util.m, descrever_sinal.m,
%   harmonicos_thd.m, fase_swrdft.m, SWRDFT.m (estimativa de frequencia
%   no notch_analyze)

clear; close all; clc;

%% ================= 1. SINAL TESTADO =================
% Mesma ponte de 6 pulsos dos testes 1 e 2.
Fs       = 62.5e3;
f0       = 60;
nCiclos  = 12;
Vll      = 480;
alphaDeg = 35;
muDeg    = 9;
Ls       = 30e-6;
Lt       = 70e-6;
snr      = 55;                              % ruido fixo [dB]

sinal = {'Modo', 'conversor', 'Fs', Fs, 'f0', f0, 'nCiclos', nCiclos, ...
         'Vll', Vll, 'Grandeza', 'fase-fase', ...
         'alphaDeg', alphaDeg, 'muDeg', muDeg, 'Ls', Ls, 'Lt', Lt, ...
         'Bits', [], 'SNRdb', snr};

% O que este teste acrescenta: harmonicos de fundo, em varios niveis.
niveisTHD = [0 0.02 0.04 0.06 0.08 0.10];

% Composicao harmonica no nivel mais alto
Hmax = harmonicos_thd(max(niveisTHD));
fprintf('HARMONICOS NO NIVEL MAIS ALTO (THD %g %%)\n', 100*max(niveisTHD));
fprintf('%8s | %14s | %12s\n', 'ordem', 'amplitude [%]', 'amplitude [V]');
Vp = sqrt(2)*Vll;
for r = 1:size(Hmax,1)
    fprintf('%7da | %14.2f | %12.1f\n', Hmax(r,1), 100*Hmax(r,2), Vp*Hmax(r,2));
end
fprintf('(nos outros niveis, as mesmas proporcoes em escala menor)\n');

% Exemplo do sinal no nivel mais alto, so para visualizacao
[x, t, truth, meta] = gerar_sinal_teste(sinal{:}, 'Harmonicos', Hmax, 'Semente', 1);
xRef = gerar_sinal_teste(sinal{:}, 'Harmonicos', Hmax, 'Semente', 1, ...
                         'Ls', 0, 'SNRdb', []);           % sem entalhe, sem ruido
descrever_sinal(x, t, truth, meta, ...
                sprintf('ruido de %g dB e THD de %g %%', snr, 100*max(niveisTHD)), xRef);

%% ================= 2. AVALIACAO =================
sementes = [1 2 3];
crit = escada_util('criterios');

escada_util('cabecalho', sprintf('TESTE 3 - harmonicos de fundo, ruido de %g dB', snr));
resultados = struct('thd', {}, 'S', {}, 'veredito', {});
for thd = niveisTHD
    S = avaliar_cenario([sinal {'Harmonicos', harmonicos_thd(thd)}], sementes);
    v = escada_util('veredito', S, crit);
    escada_util('linha', sprintf('THD %g %%', 100*thd), S, v);
    resultados(end+1) = struct('thd', thd, 'S', S, 'veredito', v);   %#ok<SAGROW>
end

%% ================= 3. RESULTADO =================
vs = {resultados.veredito};
iOK = find(strcmp(vs, 'OK'), 1, 'last');
iQB = find(strcmp(vs, 'QUEBROU'), 1, 'first');

fprintf('\nRESUMO\n');
if ~isempty(iOK)
    fprintf('  OK ate .................... THD %g %%\n', 100*resultados(iOK).thd);
end
if ~isempty(iQB)
    fprintf('  quebra a partir de ........ THD %g %%\n', 100*resultados(iQB).thd);
else
    fprintf('  nao quebrou na faixa testada\n');
end

p90 = arrayfun(@(r) r.S.prof(2), resultados);
fprintf('  P90 de profundidade ....... de %.1f %% (sem harmonicos) a %.1f %% (THD %g %%)\n', ...
        p90(1), p90(end), 100*niveisTHD(end));
fprintf('\nCOMO LER\n');
fprintf('  verd = entalhes verdadeiros depois do aquecimento (o primeiro ciclo),\n');
fprintf('  somados nas %d sementes.\n', numel(sementes));
fprintf('  Se os numeros nao mudam com o THD, o banco de ressonadores esta\n');
fprintf('  reproduzindo os harmonicos durante o entalhe, como deveria.\n');

pasta = fileparts(mfilename('fullpath'));
save(fullfile(pasta, 'resultado_teste_3.mat'), 'resultados', 'crit', 'sinal', 'sementes');
fprintf('\nResultado gravado em resultado_teste_3.mat\n');
