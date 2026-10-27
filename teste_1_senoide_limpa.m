%% TESTE 1 - SENOIDE LIMPA COM ENTALHES
%
% Primeiro degrau da escada de escalabilidade.
%
% PERGUNTA
%   No caso mais simples possivel -- entalhes sobre uma senoide perfeita,
%   sem ruido, sem harmonicos, sem nenhuma outra perturbacao --, a cadeia
%   detecta e mede todos os entalhes corretamente?
%
% RESULTADO ESPERADO
%   OK: todos os entalhes detectados, nenhum falso, erros proximos de zero.
%   Se este teste falhar, nenhum dos seguintes faz sentido.
%
% ARQUIVOS NECESSARIOS (todos nesta pasta)
%   gerar_sinal_teste.m, notch_analyze.m, notch_detector.m,
%   parear_eventos.m, avaliar_cenario.m, escada_util.m, descrever_sinal.m,
%   fase_swrdft.m, SWRDFT.m (estimativa de frequencia no notch_analyze)

clear; close all; clc;

%% ================= 1. SINAL TESTADO =================
% Ponte tiristorizada de 6 pulsos alimentada por uma rede de 480 V.
% Mede-se a tensao fase-fase v_ab, que tem 6 entalhes por ciclo:
% 2 profundos (comutacao do proprio par a-b) e 4 com metade da
% profundidade (comutacoes que envolvem a fase c).

Fs       = 62.5e3;     % taxa de amostragem [S/s]
f0       = 60;         % frequencia da rede [Hz]
nCiclos  = 12;         % duracao do registro
Vll      = 480;        % tensao fase-fase eficaz [V]
alphaDeg = 35;         % angulo de disparo dos tiristores [graus]
muDeg    = 9;          % angulo de sobreposicao (largura do entalhe) [graus]
Ls       = 30e-6;      % indutancia da fonte [H]
Lt       = 70e-6;      % indutancia de isolamento [H]  -> rho = 30 %

sinal = {'Modo', 'conversor', 'Fs', Fs, 'f0', f0, 'nCiclos', nCiclos, ...
         'Vll', Vll, 'Grandeza', 'fase-fase', ...
         'alphaDeg', alphaDeg, 'muDeg', muDeg, 'Ls', Ls, 'Lt', Lt, ...
         'Bits', []};                      % sem quantizacao
% Nenhum ruido e nenhum harmonico: nada mais e acrescentado.

[x, t, truth, meta] = gerar_sinal_teste(sinal{:}, 'Semente', 1);
xRef = gerar_sinal_teste(sinal{:}, 'Semente', 1, 'Ls', 0);   % sem entalhes

descrever_sinal(x, t, truth, meta, 'senoide limpa com entalhes', xRef);

%% ================= 2. AVALIACAO =================
% Sem ruido o sinal e deterministico: uma unica semente basta, porque
% qualquer outra daria exatamente o mesmo sinal.
sementes = 1;
crit = escada_util('criterios');

S = avaliar_cenario(sinal, sementes);
v = escada_util('veredito', S, crit);

%% ================= 3. RESULTADO =================
escada_util('cabecalho', 'TESTE 1 - senoide limpa');
escada_util('linha', 'limpo', S, v);

fprintf('\nveredito: %s\n', v);
fprintf('  entalhes verdadeiros ...... %d\n', S.nVerd);
fprintf('  detectados ................ %d   falsos: %d   perdidos: %d\n', ...
        S.nDet, S.nFalsos, S.nPerdidos);
fprintf('  conversor identificado .... %d pulsos\n', S.Np);
fprintf('  erro de profundidade ...... mediana %+.1f %%, P90 %.1f %%\n', S.prof);
fprintf('  erro de area .............. mediana %+.1f %%, P90 %.1f %%\n', S.area);
fprintf('  erro de largura ........... mediana %+.1f %%, P90 %.1f %%\n', S.larg);
fprintf('\n(o sinal tem %d entalhes; os do primeiro ciclo ficam fora da\n', ...
        numel(truth(strcmp({truth.tipo}, 'entalhe'))));
fprintf(' avaliacao, porque o detector ainda esta aquecendo -- restam %d)\n', S.nVerd);
fprintf('\n(o erro de largura de ~+3 %% e de uma amostra na contagem das\n');
fprintf(' bordas, uma convencao, nao uma falha)\n');

pasta = fileparts(mfilename('fullpath'));
save(fullfile(pasta, 'resultado_teste_1.mat'), 'S', 'v', 'crit', 'sinal', 'sementes');
fprintf('\nResultado gravado em resultado_teste_1.mat\n');
