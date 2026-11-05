%% TESTE_VARRER_PARAMETROS - o teste de N sinais para varias frequencias e ruidos
%
% Roda nSinais sinais de parametros iguais, comparando cada um com a
% verdade, para CADA combinacao de frequencia e ruido listada abaixo.
% Para olhar uma condicao so, em detalhe: uma frequencia, um ruido e
% mostrarTabelas = true (a tabela sinal a sinal).  Para so ver um sinal
% de exemplo, sem rodar nada: soExemplo = true.
%
% Para cada combinacao:
%   - roda os nSinais sinais e compara com a verdade (rodar_conjunto.m);
%   - grava o arquivo da combinacao em resultados/ (res_...mat).
% No final:
%   - mostra uma tabela com UMA LINHA POR COMBINACAO, e uma legenda;
%   - grava um arquivo consolidado, resultados/varredura_...mat, pronto
%     para graficos (por exemplo, erro do angulo em funcao da frequencia).
%
% Todas as combinacoes usam as MESMAS sementes (sementeBase+1 ...): a
% diferenca entre elas vem so da frequencia e do ruido, nao do acaso.
%
% TEMPO: ~0,1 s por sinal no MATLAB (~4 s no Octave).  11 frequencias x
% 100 sinais levam ~2 min no MATLAB.
%
% ARQUIVOS NECESSARIOS: os da pasta (usa rodar_conjunto.m)

clear; clc;

%% ================= 1. O QUE VARRER =================
freqs = 55:1:65;       % <-- ALTERE AQUI: frequencias reais da rede [Hz]
                       %     ex.: 55:1:65 (11 valores), 55:0.1:65 (101 valores)
snrs  = [65 55 45];            % <-- ALTERE AQUI: niveis de ruido [dB]
                       %     ex.: 55, ou [65 55 45] (varre todas as combinacoes)

%% ================= 2. O QUE FICA FIXO EM TODAS AS COMBINACOES =================
nSinais     = 100;     % <-- ALTERE AQUI: sinais por combinacao
sementeBase = 0;       % <-- ALTERE AQUI: sementes sementeBase+1 ... sementeBase+nSinais

% harmonicas de fundo: por DHI [ordem  DHI(%)  fase(graus)], ou DHI = []
% para usar thdTotal
DHI = [  5    3.0    17.2      % <-- ALTERE AQUI: 5a  harmonica, DHI em %
         7    2.0    34.4      % <-- ALTERE AQUI: 7a  harmonica
        11    0.0    51.6      % <-- ALTERE AQUI: 11a harmonica (0 = ausente)
        13    0.0    68.8 ];   % <-- ALTERE AQUI: 13a harmonica (0 = ausente)
thdTotal = 0.04;       % <-- ALTERE AQUI: THD total, usado so se DHI = []

% conversor e aquisicao (normalmente nao mudam)
% influenciaFreq = true: mede tambem a influencia da frequencia estimada pela
% SWRDFT na area -- roda o detector uma 2a vez, na frequencia verdadeira, e
% grava a diferenca (figura 4 do graficos_varredura).  false = mais rapido.
cfg = struct( ...
    'Fs',       62.5e3, ...    % taxa de amostragem [S/s]
    'f0',       60, ...        % frequencia NOMINAL (a cadeia estima a real)
    'nCiclos',  12, ...        % duracao de cada sinal [ciclos]
    'Vll',      480, ...       % tensao fase-fase eficaz [V]
    'alphaDeg', 35, ...        % angulo de disparo dos tiristores [graus]
    'muDeg',    9, ...         % angulo de sobreposicao [graus]
    'Ls',       30e-6, ...     % indutancia da fonte [H]
    'Lt',       70e-6, ...     % indutancia de isolamento [H] (rho = 30 %)
    'influenciaFreq', true, ...    % <-- ALTERE AQUI: influencia da SWRDFT na area (ver acima)
    'refAngulo', 'fundamental');   % referencia do angulo verdadeiro: a fundamental
                                   % do proprio sinal com entalhes (fixa; os arquivos
                                   % saem com o sufixo _reffund)

mostrarTabelas = false;  % <-- ALTERE AQUI: true mostra a tabela de cada
                         %     combinacao (sao nSinais linhas cada)
mostrarExemplo = true;   % <-- ALTERE AQUI: true desenha UM sinal de exemplo,
                         %     com o que a cadeia mede, antes da varredura
soExemplo      = false;  % <-- ALTERE AQUI: true = SO desenha o exemplo e para
                         %     (nao roda a varredura; leva segundos)
exemploFreq    = [];     % <-- ALTERE AQUI: frequencia do exemplo [Hz]
                         %     ([] = a do meio da lista freqs)
exemploSNR     = [];     % <-- ALTERE AQUI: ruido do exemplo [dB] ([] = o 1o de snrs)
exemploSinal   = 1;      % <-- ALTERE AQUI: qual sinal (1 a nSinais); com os mesmos
                         %     parametros, e IDENTICO ao que a varredura analisa

%% ================= 3. EXECUCAO =================
freqs = round(freqs(:)'*1000)/1000;     % limpa erros de arredondamento (55.1 etc.)
snrs  = snrs(:)';

% ---------- um sinal de exemplo (o mesmo que a varredura vai analisar) ----------
if mostrarExemplo || soExemplo
    if isempty(DHI)
        Hx = harmonicos_thd(thdTotal);
        txtH = sprintf('THD %.1f %%', 100*thdTotal);
    else
        Dx = DHI(DHI(:,2) > 0, :);
        Hx = [Dx(:,1), Dx(:,2)/100, deg2rad(Dx(:,3))];
        txtH = strjoin(arrayfun(@(q) sprintf('%da %.1f %%', Dx(q,1), Dx(q,2)), ...
                                1:size(Dx,1), 'UniformOutput', false), ', ');
        if isempty(Dx), Hx = zeros(0, 3); txtH = 'sem harmonicas'; end
    end
    fx = exemploFreq;  if isempty(fx), fx = freqs(ceil(numel(freqs)/2)); end
    sx = exemploSNR;   if isempty(sx), sx = snrs(1); end
    opx = {'Modo', 'conversor', 'Fs', cfg.Fs, 'f0', cfg.f0, 'nCiclos', cfg.nCiclos, ...
           'Vll', cfg.Vll, 'Grandeza', 'fase-fase', 'alphaDeg', cfg.alphaDeg, ...
           'muDeg', cfg.muDeg, 'Ls', cfg.Ls, 'Lt', cfg.Lt, 'Bits', [], ...
           'SNRdb', sx, 'Harmonicos', Hx, 'DesvioFreqHz', fx - cfg.f0, ...
           'Semente', sementeBase + exemploSinal};
    [xEx, tEx, trEx, metaEx] = gerar_sinal_teste(opx{:});
    xRefEx = gerar_sinal_teste(opx{:}, 'Ls', 0, 'SNRdb', []);     % sem entalhes nem ruido
    descrever_sinal(xEx, tEx, trEx, metaEx, ...
        sprintf('rede em %g Hz, ruido %g dB, %s, sinal %d', fx, sx, txtH, exemploSinal), xRefEx);
    fprintf('\n');
    if soExemplo
        fprintf('soExemplo = true: so o exemplo foi desenhado; a varredura nao foi rodada.\n');
        return;
    end
end
nC = numel(freqs)*numel(snrs);

fprintf('VARREDURA: %d frequencias x %d nivel(is) de ruido = %d combinacoes, %d sinais cada\n\n', ...
        numel(freqs), numel(snrs), nC, nSinais);

campos = {'f', 'snr', 'entalhes', 'falsos', 'perdidos', 'sinaisComFalso', ...
          'erroFMedio', 'erroFPior', 'profP90', 'areaP90', 'largP90', ...
          'angRms', 'angP90', 'angPior', 'tempo'};
for q = 1:numel(campos), combinacoes.(campos{q}) = zeros(nC, 1); end
combinacoes.arquivo = cell(nC, 1);

c = 0;
for s = snrs
    for f = freqs
        c = c + 1;
        [R, arq] = rodar_conjunto(f, s, nSinais, sementeBase, DHI, thdTotal, cfg, mostrarTabelas);
        combinacoes.f(c) = f;                 combinacoes.snr(c) = s;
        combinacoes.entalhes(c) = R.entalhes; combinacoes.falsos(c) = R.falsos;
        combinacoes.perdidos(c) = R.perdidos; combinacoes.sinaisComFalso(c) = R.sinaisComFalso;
        combinacoes.erroFMedio(c) = R.erroFMedio;  combinacoes.erroFPior(c) = R.erroFPior;
        combinacoes.profP90(c) = R.profP90;   combinacoes.areaP90(c) = R.areaP90;
        combinacoes.largP90(c) = R.largP90;
        combinacoes.angRms(c) = R.angRms;     combinacoes.angP90(c) = R.angP90;
        combinacoes.angPior(c) = R.angPior;   combinacoes.tempo(c) = R.tempoTotal;
        [~, nomeArq, ext] = fileparts(arq);   combinacoes.arquivo{c} = [nomeArq ext];
        fprintf('  %3d de %d  |  %6.2f Hz, %g dB  |  falsos %d, perdidos %d  |  area P90 %.2f %%, angulo pior %.2f graus  |  %.0f s\n', ...
                c, nC, f, s, R.falsos, R.perdidos, R.areaP90, R.angPior, R.tempoTotal);
    end
end

%% ================= 4. TABELA CONSOLIDADA =================
sep = repmat('-', 1, 108);
fprintf('\nRESULTADO DA VARREDURA (uma linha por combinacao; %d sinais cada)\n', nSinais);
fprintf('%s\n', sep);
fprintf('%7s | %4s | %8s | %4s %4s %5s | %10s %9s | %8s %8s %8s | %7s %7s %7s\n', ...
        'rede', 'SNR', 'entalhes', 'fal', 'per', 'sinF', 'erro f', 'erro f', ...
        'prof P90', 'area P90', 'larg P90', 'ang RMS', 'ang P90', 'ang max');
fprintf('%7s | %4s | %8s | %4s %4s %5s | %10s %9s | %8s %8s %8s | %7s %7s %7s\n', ...
        '[Hz]', '[dB]', '', '', '', '', 'medio [Hz]', 'pior [Hz]', ...
        '[%]', '[%]', '[%]', '[graus]', '[graus]', '[graus]');
fprintf('%s\n', sep);
for c = 1:nC
    fprintf('%7.2f | %4g | %8d | %4d %4d %5d | %+10.5f %9.5f | %8.2f %8.2f %8.2f | %7.2f %7.2f %7.2f\n', ...
            combinacoes.f(c), combinacoes.snr(c), combinacoes.entalhes(c), ...
            combinacoes.falsos(c), combinacoes.perdidos(c), combinacoes.sinaisComFalso(c), ...
            combinacoes.erroFMedio(c), combinacoes.erroFPior(c), ...
            combinacoes.profP90(c), combinacoes.areaP90(c), combinacoes.largP90(c), ...
            combinacoes.angRms(c), combinacoes.angP90(c), combinacoes.angPior(c));
end
fprintf('%s\n', sep);
fprintf('LEGENDA (cada linha resume os %d sinais de uma combinacao, com os erros\n', nSinais);
fprintf('de todos os entalhes juntos)\n');
fprintf('  rede, SNR .... frequencia real e ruido da combinacao\n');
fprintf('  entalhes ..... entalhes verdadeiros avaliados, somados nos sinais\n');
fprintf('  fal, per ..... eventos falsos e entalhes perdidos, somados nos sinais\n');
fprintf('  sinF ......... quantos sinais tiveram ao menos um evento falso\n');
fprintf('  erro f ....... frequencia estimada - real: media e pior caso entre os sinais\n');
fprintf('  prof/area/larg P90 ... 90 %% dos entalhes tem erro menor que isso\n');
fprintf('  ang RMS/P90/max ...... erro do angulo dos entalhes: RMS, P90 e maior\n');

%% ================= 5. ARQUIVO CONSOLIDADO =================
% resultados/varredura_<frequencias>_<ruidos>_<harmonicas>_n<N>_s<base>.mat
%   combinacoes  um campo por coluna da tabela, uma linha por combinacao,
%                mais o nome do arquivo de cada combinacao
%   fixos        o que ficou igual em todas (sinais, sementes, harmonicas,
%                conversor, programa, data)
% Exemplo:  S = load('resultados/varredura_...mat');
%           plot(S.combinacoes.f, S.combinacoes.angRms, '-o')
num = @(v) strrep(sprintf('%g', v), '.', 'p');
% trecho do nome para uma lista de valores: um valor ou "minimo-maximo"
if numel(freqs) == 1, parteF = ['f' num(freqs)];
else, parteF = ['f' num(min(freqs)) '-' num(max(freqs))]; end
if numel(snrs) == 1, parteS = ['snr' num(snrs)];
else, parteS = ['snr' num(min(snrs)) '-' num(max(snrs))]; end
if isempty(DHI)
    parteH = ['thd' num(round(1000*thdTotal)/10)];
else
    Dn = DHI(DHI(:,2) > 0, :);
    if isempty(Dn), parteH = 'h0'; else, parteH = 'h'; end
    for q = 1:size(Dn, 1)
        if q > 1, parteH = [parteH '_']; end                               %#ok<AGROW>
        parteH = [parteH sprintf('%d-', Dn(q,1)) num(Dn(q,2))];            %#ok<AGROW>
    end
end
% referencia do angulo: 'ideal' mantem o nome de sempre; 'fundamental'
% ganha o sufixo _reffund, para os dois conjuntos conviverem na pasta
sufRef = '';
if isfield(cfg, 'refAngulo') && strcmp(cfg.refAngulo, 'fundamental'), sufRef = '_reffund'; end
nome = sprintf('varredura_%s_%s_%s_n%d_s%d%s.mat', parteF, parteS, ...
               parteH, nSinais, sementeBase, sufRef);
if exist('OCTAVE_VERSION', 'builtin')        % com qual programa os resultados foram gerados
    progVersao = ['Octave ' OCTAVE_VERSION];
else
    progVersao = ['MATLAB ' version('-release')];
end
fixos = struct('nSinais', nSinais, 'sementeBase', sementeBase, 'DHI', DHI, ...
               'thdTotal', thdTotal, 'conversor', cfg, 'freqs', freqs, 'snrs', snrs, ...
               'regraDecisao', 'secante', 'programa', progVersao, ...
               'data', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
pasta = fullfile(fileparts(mfilename('fullpath')), 'resultados');
if ~exist(pasta, 'dir'), mkdir(pasta); end
save(fullfile(pasta, nome), 'combinacoes', 'fixos', '-v7');
fprintf('\nArquivo consolidado: resultados/%s\n', nome);
fprintf('Arquivos de cada combinacao: os %d res_...mat listados em combinacoes.arquivo\n', nC);
