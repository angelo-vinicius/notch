function [resumo, arquivo, res] = rodar_conjunto(fReal, snr, nSinais, sementeBase, ...
                                            DHI, thdTotal, cfg, mostrar)
% RODAR_CONJUNTO
%
% Roda nSinais sinais com os MESMOS parametros (so o ruido muda), compara
% cada um com a verdade de campo, resume o conjunto e grava um arquivo
% .mat em resultados/, com o nome montado a partir dos parametros.
%
% E o miolo do teste_varrer_parametros.m, que o chama uma vez para cada
% combinacao de frequencia e ruido.
%
%   [resumo, arquivo, res] = rodar_conjunto(fReal, snr, nSinais, sementeBase, ...
%                                           DHI, thdTotal, cfg, mostrar)
%
%   fReal        frequencia real da rede [Hz]
%   snr          relacao sinal-ruido [dB]
%   nSinais      quantos sinais
%   sementeBase  os sinais usam as sementes sementeBase+1 ... sementeBase+nSinais
%   DHI          harmonicas por DHI, [ordem  DHI(%)  fase(graus)]; [] = usar thdTotal
%   thdTotal     THD total (fracao), usado se DHI = []
%   cfg          conversor e aquisicao: Fs, f0, nCiclos, Vll, alphaDeg,
%                muDeg, Ls, Lt
%   mostrar      true = imprime parametros, tabela por sinal, legenda,
%                resumo e falsos; false = so calcula e grava (padrao true)
%
%   resumo       o resumo do conjunto (o mesmo gravado no arquivo)
%   arquivo      caminho do arquivo .mat gravado
%   res          os resultados de cada sinal (saida de mc_uma_rodada)

if nargin < 8, mostrar = true; end

% imprime so quando pedido (mostrar = true)
imprime = @(varargin) mostrar && fprintf(varargin{:}) >= 0;

%% ================= 2. PREPARACAO =================
if isempty(DHI)
    cfg.H = harmonicos_thd(thdTotal);
    descrH = sprintf('THD total de %.1f %% (5a, 7a, 11a e 13a, pesos ~1/h)', 100*thdTotal);
else
    D = DHI(DHI(:,2) > 0, :);                         % ignora DHI = 0
    cfg.H = [D(:,1), D(:,2)/100, deg2rad(D(:,3))];    % [ordem pu rad]
    descrH = sprintf('por DHI, THD resultante de %.2f %%', sqrt(sum(D(:,2).^2)));
end
if isempty(cfg.H), cfg.H = zeros(0, 3); end

imprime('TESTE COM %d SINAIS DE PARAMETROS IGUAIS\n', nSinais);
imprime('  rede ............. %.2f Hz (nominal %g Hz)\n', fReal, cfg.f0);
imprime('  ruido ............ %g dB\n', snr);
imprime('  harmonicas ....... %s\n', descrH);
for q = 1:size(cfg.H, 1)
    imprime('                     %2da: %5.2f %% da fundamental, fase %5.1f graus\n', ...
            cfg.H(q,1), 100*cfg.H(q,2), rad2deg(cfg.H(q,3)));
end
fora = setdiff(cfg.H(:,1)', [5 7 11 13]);
if ~isempty(fora)
    imprime('  ATENCAO: a(s) ordem(ns) %s nao estao no banco de ressonadores\n', mat2str(fora));
    imprime('           (ordens 1, 5, 7, 11, 13): parte delas ira para o erro da medicao\n');
end
imprime('  conversor ........ 6 pulsos, alpha %g graus, mu %g graus, %g kS/s, %d ciclos\n', ...
        cfg.alphaDeg, cfg.muDeg, cfg.Fs/1e3, cfg.nCiclos);
imprime('  sementes ......... %d a %d\n\n', sementeBase + 1, sementeBase + nSinais);

%% ================= 3. EXECUCAO =================
sep = repmat('-', 1, 104);
imprime('%4s | %7s | %10s | %9s | %4s %4s %4s %4s | %8s %8s %8s | %7s %7s | %5s\n', ...
        'n', 'semente', 'f estimada', 'erro f', 'verd', 'det', 'fal', 'per', ...
        'prof P90', 'area P90', 'larg P90', 'ang RMS', 'ang max', 'tempo');
imprime('%4s | %7s | %10s | %9s | %4s %4s %4s %4s | %8s %8s %8s | %7s %7s | %5s\n', ...
        '', '', '[Hz]', '[Hz]', '', '', '', '', '[%]', '[%]', '[%]', '[graus]', '[graus]', '[s]');
imprime('%s\n', sep);

res = [];
for k = 1:nSinais
    semente = sementeBase + k;
    r = mc_uma_rodada(fReal, snr, semente, cfg);
    res = [res; r];                                                  %#ok<AGROW>
    marca = '';
    if r.falsos + r.perdidos > 0, marca = '  <--'; end
    imprime('%4d | %7d | %10.4f | %+9.5f | %4d %4d %4d %4d | %8.1f %8.1f %8.1f | %7.2f %7.2f | %5.1f%s\n', ...
            k, semente, r.fEst, r.erroF, r.nVerd, r.nDet, r.falsos, r.perdidos, ...
            r.profP90, r.areaP90, r.largP90, r.totRms, r.totPior, r.tempo, marca);
end
imprime('%s\n', sep);

imprime('LEGENDA\n');
imprime('  n ............ numero do sinal\n');
imprime('  semente ...... semente do ruido; reproduz o sinal com mc_uma_rodada\n');
imprime('  f estimada ... frequencia da rede estimada pela SWRDFT (media do registro)\n');
imprime('  erro f ....... f estimada - f real\n');
imprime('  verd ......... entalhes verdadeiros avaliados (o 1o ciclo fica de fora: aquecimento)\n');
imprime('  det .......... eventos detectados\n');
imprime('  fal .......... eventos falsos: sem entalhe verdadeiro correspondente\n');
imprime('  per .......... entalhes perdidos: sem evento correspondente\n');
imprime('  prof P90 ..... 90 %% dos entalhes tem erro de profundidade menor que isso\n');
imprime('  area P90 ..... o mesmo para a area (a grandeza usada pela IEEE 519)\n');
imprime('  larg P90 ..... o mesmo para a largura (inclui o vies fixo de ~+3,7 %%, 1 amostra)\n');
imprime('  ang RMS ...... erro RMS do angulo dos entalhes (medido x verdadeiro, no centro verdadeiro)\n');
imprime('  ang max ...... maior erro de angulo entre os entalhes do sinal\n');
imprime('  <-- .......... sinal com algum evento falso ou entalhe perdido\n');

%% ================= 4. RESUMO DO CONJUNTO =================
% os erros de TODOS os entalhes dos sinais, juntos
eP = [res.eProf];  eA = [res.eArea];  eL = [res.eLarg];  eG = [res.eAng];
p90 = @(v) escada_util('p90', v);
nVerd = sum([res.nVerd]);  nFal = sum([res.falsos]);  nPer = sum([res.perdidos]);
kFal = sum([res.falsos] > 0);

imprime('\nRESUMO DOS %d SINAIS (erros de todos os entalhes juntos)\n', nSinais);
imprime('  entalhes avaliados ....... %d\n', nVerd);
imprime('  falsos / perdidos ........ %d / %d   (sinais com falso: %d de %d)\n', ...
        nFal, nPer, kFal, nSinais);
imprime('  frequencia ............... erro medio %+.5f Hz, pior %.5f Hz\n', ...
        mean([res.erroF]), max(abs([res.erroF])));
imprime('  profundidade ............. mediana %+.2f %%, P90 %.2f %%\n', median(eP), p90(eP));
imprime('  area ..................... mediana %+.2f %%, P90 %.2f %%\n', median(eA), p90(eA));
imprime('  largura .................. mediana %+.2f %%, P90 %.2f %%\n', median(eL), p90(eL));
imprime('  angulo ................... RMS %.2f graus, P90 %.2f graus, pior %.2f graus\n', ...
        sqrt(mean(eG.^2)), p90(eG), max(abs(eG)));
imprime('  tempo .................... %.0f s no total, %.2f s por sinal\n', ...
        sum([res.tempo]), mean([res.tempo]));

if nFal > 0
    imprime('\nEVENTOS FALSOS (%d)\n', nFal);
    imprime('%4s | %7s | %10s | %14s | %8s | %12s\n', 'n', 'semente', 'instante', ...
            'angulo na onda', 'amostras', 'profundidade');
    for k = find([res.falsos] > 0)
        Df = res(k).detFalsos;
        for q = 1:size(Df, 1)
            imprime('%4d | %7d | %7.2f ms | %11.1f g | %8d | %10.2f V\n', ...
                    k, res(k).semente, 1e3*Df(q,1), Df(q,2), Df(q,3), Df(q,4));
        end
    end
    imprime('(o pico da tensao fase-fase fica em 90 e 270 graus)\n');
end

%% ================= 5. GRAVAR OS RESULTADOS =================
% Um arquivo .mat por conjunto de parametros, com o nome montado a partir
% deles, na pasta resultados/.  Rodar de novo com os mesmos parametros
% regrava o mesmo arquivo (mesmas sementes = mesmo resultado).
%
% CONTEUDO DO ARQUIVO
%   parametros  tudo o que gerou o conjunto (rede, ruido, harmonicas,
%               conversor, sementes, regra de decisao, data)
%   porSinal    a tabela da tela: um campo por coluna, uma linha por sinal
%               (no MATLAB: T = struct2table(porSinal)), mais rmsF: o erro
%               RMS da estimativa de frequencia AMOSTRA A AMOSTRA da SWRDFT
%               no registro (a oscilacao mostrada no teste 4)
%   resumo      o resumo do conjunto (erros de todos os entalhes juntos)
%   erros       os erros de CADA entalhe pareado, de todos os sinais:
%               profundidade, area e largura [%], angulo [graus].  O
%               angulo tem menos valores: os entalhes das duas primeiras
%               janelas da SWRDFT nao tem angulo
%   falsos      um evento falso por linha: [n semente instante(s)
%               angulo_na_onda(graus) amostras profundidade(V)]
%
% COMO LER
%   S = load('resultados/<nome>.mat');
%   S.resumo.areaP90, S.porSinal.angRms, histogram(S.erros.area), ...

% ---------- parametros ----------
if exist('OCTAVE_VERSION', 'builtin')        % com qual programa os resultados foram gerados
    progVersao = ['Octave ' OCTAVE_VERSION];
else
    progVersao = ['MATLAB ' version('-release')];
end
parametros = struct('fReal', fReal, 'snr', snr, 'nSinais', nSinais, ...
    'sementeBase', sementeBase, 'sementes', sementeBase + (1:nSinais), ...
    'harmonicas', cfg.H, ...                      % [ordem pu rad]
    'harmonicasTexto', descrH, 'DHI', DHI, 'thdTotal', thdTotal, ...
    'thdResultante', 100*sqrt(sum(cfg.H(:,2).^2)), ...
    'conversor', rmfield(cfg, 'H'), 'regraDecisao', 'secante', ...
    'data', datestr(now, 'yyyy-mm-dd HH:MM:SS'), 'programa', progVersao);

% ---------- a tabela, uma coluna por campo ----------
porSinal = struct( ...
    'n',        (1:nSinais)', ...
    'semente',  [res.semente]', ...
    'fEst',     [res.fEst]', ...       % frequencia estimada [Hz]
    'erroF',    [res.erroF]', ...      % f estimada - f real [Hz]
    'rmsF',     [res.rmsF]', ...       % RMS da estimativa amostra a amostra [Hz]
    'verd',     [res.nVerd]', ...      % entalhes verdadeiros avaliados
    'det',      [res.nDet]', ...       % eventos detectados
    'falsos',   [res.falsos]', ...
    'perdidos', [res.perdidos]', ...
    'profP90',  [res.profP90]', ...    % [%]
    'areaP90',  [res.areaP90]', ...    % [%]
    'largP90',  [res.largP90]', ...    % [%]
    'angRms',   [res.totRms]', ...     % [graus]
    'angMax',   [res.totPior]', ...    % [graus]
    'tempo',    [res.tempo]');         % [s]

% ---------- o resumo ----------
resumo = struct('entalhes', nVerd, 'falsos', nFal, 'perdidos', nPer, ...
    'sinaisComFalso', kFal, ...
    'erroFMedio', mean([res.erroF]), 'erroFPior', max(abs([res.erroF])), ...
    'profMediana', median(eP), 'profP90', p90(eP), ...
    'areaMediana', median(eA), 'areaP90', p90(eA), ...
    'largMediana', median(eL), 'largP90', p90(eL), ...
    'angRms', sqrt(mean(eG.^2)), 'angP90', p90(eG), 'angPior', max(abs(eG)), ...
    'tempoTotal', sum([res.tempo]));

% ---------- erros por entalhe e falsos ----------
eAF = [res.eAreaFreq];      % vazio se a opcao influenciaFreq estiver desligada
erros = struct('prof', eP(:), 'area', eA(:), 'larg', eL(:), 'ang', eG(:), ...
               'areaFreq', eAF(:));
falsos = zeros(0, 6);
for k = find([res.falsos] > 0)
    Df = res(k).detFalsos;
    falsos = [falsos; repmat([k res(k).semente], size(Df, 1), 1), Df];   %#ok<AGROW>
end

% ---------- nome do arquivo a partir dos parametros ----------
num = @(v) strrep(sprintf('%g', v), '.', 'p');    % 60.5 -> 60p5
if isempty(DHI)
    parteH = ['thd' num(round(1000*thdTotal)/10)];
else
    Dn = DHI(DHI(:,2) > 0, :);
    parteH = 'h';
    for q = 1:size(Dn, 1)
        if q > 1, parteH = [parteH '_']; end                               %#ok<AGROW>
        parteH = [parteH sprintf('%d-', Dn(q,1)) num(Dn(q,2))];            %#ok<AGROW>
    end
    if size(Dn, 1) == 0, parteH = 'h0'; end
end
% referencia do angulo: 'ideal' mantem o nome de sempre; 'fundamental'
% ganha o sufixo _reffund, para os dois conjuntos conviverem na pasta
sufRef = '';
if isfield(cfg, 'refAngulo') && strcmp(cfg.refAngulo, 'fundamental'), sufRef = '_reffund'; end
nome = sprintf('res_f%s_snr%s_%s_n%d_s%d%s.mat', num(fReal), num(snr), parteH, ...
               nSinais, sementeBase, sufRef);

pasta = fullfile(fileparts(mfilename('fullpath')), 'resultados');
if ~exist(pasta, 'dir'), mkdir(pasta); end
arquivo = fullfile(pasta, nome);
save(arquivo, 'parametros', 'porSinal', 'resumo', 'erros', 'falsos', '-v7');
imprime('\nResultados gravados em resultados/%s\n', nome);

end
