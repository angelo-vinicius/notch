%% GRAFICOS_VARREDURA - todos os graficos de validacao da varredura
%
% Le os arquivos res_*.mat gravados pelo teste_varrer_parametros.m e
% desenha, de uma vez, com uma curva por nivel
% de ruido:
%
%   FIGURA 1 - erro da AREA x frequencia da rede, em tres paineis (o
%              painel B mostra o ERRO RMS DA ESTIMATIVA DE FREQUENCIA DA
%              SWRDFT AMOSTRA A AMOSTRA, o "U" centrado em 60 Hz):
%              A) erro de cada entalhe: a media (ponto) e do menor ao
%                 maior erro (barra), um nivel de ruido ao lado do outro;
%              B) media do valor absoluto;
%              C) desvio-padrao
%   FIGURA 2 - erro do ANGULO x frequencia, nos mesmos tres paineis
%   FIGURA 3 - erro da FREQUENCIA estimada pela cadeia (a media de cada
%              registro, que sintoniza o detector), em mHz: a media
%              (ponto) e do menor ao maior erro dos sinais (barra)
%
% Cada ponto usa os erros de TODOS os entalhes (ou de todos os sinais, na
% frequencia) de uma combinacao.  Nada e simulado aqui: so le e desenha.
%
% QUAIS ARQUIVOS ENTRAM
%   So arquivos com as MESMAS condicoes fixas (harmonicas, numero de
%   sinais, sementeBase, conversor e regra de decisao).  Se a pasta tiver
%   rodadas diferentes, o script lista os grupos e usa o maior -- ou o
%   escolhido em grupoEscolhido.
%
% GRAVA (se gravarFiguras = true), em <pastaResultados>/graficos/:
%   erro_area_<condicoes>.png/.fig/.mat, erro_angulo_..., erro_frequencia_...
%   (.fig so no MATLAB; o .mat tem os valores de cada ponto)
%
% ARQUIVOS NECESSARIOS: os res_*.mat em resultados/

clear; clc;
fprintf('graficos_varredura -- versao de 05/11/2026: erro RMS da frequencia (SWRDFT) no painel B da area\n\n');

%% ================= 1. OPCOES =================
pastaResultados = 'resultados';   % <-- ALTERE AQUI: pasta com os res_*.mat
grupoEscolhido  = [];             % <-- ALTERE AQUI: [] = o maior grupo; ou o
                                  %     numero do grupo listado na tela
refPlotar       = 'fundamental';  % referencia do angulo: sempre a fundamental do
                                  % proprio sinal (arquivos de outras referencias,
                                  % de versoes antigas, sao ignorados)
snrsPlotar      = [];             % <-- ALTERE AQUI: [] = todos os niveis de
                                  %     ruido; ou so alguns, ex.: 55 ou [45 65]
gravarFiguras   = true;           % <-- ALTERE AQUI: true grava PNG, .fig e os
                                  %     valores em resultados/graficos/

% cores por nivel de ruido [R G B] (outros niveis usam cores automaticas)
coresSNR = [45  0.216 0.541 0.867     % 45 dB: azul
            55  0.886 0.294 0.290     % 55 dB: vermelho
            65  0.937 0.624 0.153];   % 65 dB: laranja

%% ================= 2. LER OS ARQUIVOS (uma vez, para as tres figuras) =================
pasta = fullfile(fileparts(mfilename('fullpath')), pastaResultados);
lista = dir(fullfile(pasta, 'res_*.mat'));
if isempty(lista)
    error('graficos_varredura:vazio', 'Nenhum arquivo res_*.mat em %s', pasta);
end

dados = struct('arquivo', {}, 'f', {}, 'snr', {}, 'P', {}, 'erros', {}, ...
               'porSinal', {}, 'assin', {});
for k = 1:numel(lista)
    S = load(fullfile(pasta, lista(k).name));
    if ~isfield(S, 'parametros') || ~isfield(S, 'erros') || ~isfield(S, 'porSinal')
        continue;
    end
    p = S.parametros;  c = p.conversor;
    % "assinatura": tudo o que deve ser igual entre os pontos de um grafico
    refA = 'ideal';                      % arquivos antigos: referencia da onda ideal
    if isfield(c, 'refAngulo') && ~isempty(c.refAngulo), refA = c.refAngulo; end
    p.refAngulo = refA;
    assin = sprintf('h%s|n%d|s%d|Fs%g|a%g|mu%g|Ls%g|Lt%g|nc%d|%s|ref:%s', ...
                    mat2str(round(p.harmonicas*1e6)/1e6), p.nSinais, p.sementeBase, ...
                    c.Fs, c.alphaDeg, c.muDeg, c.Ls, c.Lt, c.nCiclos, p.regraDecisao, refA);
    dados(end+1) = struct('arquivo', lista(k).name, 'f', p.fReal, 'snr', p.snr, ...
                          'P', p, 'erros', S.erros, 'porSinal', S.porSinal, ...
                          'assin', assin);                               %#ok<AGROW>
end
if isempty(dados)
    error('graficos_varredura:vazio', 'Nenhum res_*.mat valido em %s', pasta);
end

% grupos de condicoes fixas
% so os arquivos da referencia do angulo pedida
if ~isempty(refPlotar)
    temRef = arrayfun(@(d) strcmp(d.P.refAngulo, refPlotar), dados);
    if ~any(temRef)
        error('graficos_varredura:ref', 'Nenhum arquivo com referencia do angulo ''%s''.', refPlotar);
    end
    fprintf('referencia do angulo: %s (%d de %d arquivos)\n', refPlotar, sum(temRef), numel(dados));
    dados = dados(temRef);
end
[assins, ~, ig] = unique({dados.assin});
nPorGrupo = accumarray(ig(:), 1);
fprintf('ARQUIVOS ENCONTRADOS: %d, em %d grupo(s) de condicoes fixas\n', numel(dados), numel(assins));
for g = 1:numel(assins)
    d1 = dados(find(ig == g, 1));
    fprintf('  grupo %d: %3d arquivos | %s | %d sinais | sementeBase %d | angulo: ref. %s\n', g, nPorGrupo(g), ...
            d1.P.harmonicasTexto, d1.P.nSinais, d1.P.sementeBase, d1.P.refAngulo);
end
if isempty(grupoEscolhido)
    [~, grupoEscolhido] = max(nPorGrupo);
end
dados = dados(ig == grupoEscolhido);
% protecao: duas rodadas da mesma combinacao no mesmo grupo -> fica a mais recente
chave = arrayfun(@(d) sprintf('%.3f|%g', d.f, d.snr), dados, 'UniformOutput', false);
[chU, ~, ic] = unique(chave);
if numel(chU) < numel(dados)
    manter = false(1, numel(dados));
    for q = 1:numel(chU)
        iq = find(ic == q);
        [~, im] = max(arrayfun(@(d) datenum(d.P.data, 'yyyy-mm-dd HH:MM:SS'), dados(iq)));
        manter(iq(im)) = true;
    end
    fprintf('ATENCAO: %d arquivo(s) repetido(s) da mesma combinacao; usando o mais recente\n', ...
            numel(dados) - sum(manter));
    dados = dados(manter);
end
P0 = dados(1).P;
fprintf('usando o grupo %d (%d arquivos)\n\n', grupoEscolhido, numel(dados));

% so os niveis de ruido pedidos (snrsPlotar vazio = todos)
if ~isempty(snrsPlotar)
    disponiveis = unique([dados.snr]);
    falta = setdiff(snrsPlotar, disponiveis);
    if ~isempty(falta)
        fprintf('ATENCAO: nivel(is) de ruido %s nao existe(m) nos arquivos (disponiveis: %s)\n', ...
                mat2str(falta), mat2str(disponiveis));
    end
    dados = dados(ismember([dados.snr], snrsPlotar));
    if isempty(dados)
        error('Nenhum arquivo com os niveis de ruido pedidos em snrsPlotar.');
    end
end

%% ================= 3. FIGURAS 1 E 2: AREA E ANGULO (tres paineis) =================
dadosLidos = dados;
for grandezaFig = {'area', 'angulo'}
grandeza = grandezaFig{1};
dados = dadosLidos;
switch grandeza
    case 'area'
        campo = 'area';  nome = 'da area';  un = '%';      tagG = 'area';
    case 'angulo'
        campo = 'ang';   nome = 'do angulo'; un = 'graus'; tagG = 'angulo';
    case 'profundidade'
        campo = 'prof';  nome = 'da profundidade'; un = '%'; tagG = 'profundidade';
    case 'largura'
        campo = 'larg';  nome = 'da largura'; un = '%';    tagG = 'largura';
    otherwise
        error('grafico_erro_tres_paineis:grandeza', 'Grandeza desconhecida: %s', grandeza);
end
unTxt = un;

%% ================= CALCULAR OS PONTOS =================
freqs = unique(round([dados.f]*1000)/1000);
snrs  = sort(unique([dados.snr]));          % do mais ruidoso ao menos ruidoso
nF = numel(freqs);  nS = numel(snrs);
media = nan(nF, nS);  mn = media;  mx = media;  mAbs = media;  dp = media;  nEnt = media;

for k = 1:numel(dados)
    i = find(abs(freqs - dados(k).f) < 1e-6);
    j = find(snrs == dados(k).snr);
    e = dados(k).erros.(campo)(:);  e = e(isfinite(e));
    if isempty(e), continue; end
    v = sort(e);  n = numel(v);
    media(i,j) = mean(e);
    mn(i,j)    = v(1);                    % menor erro
    mx(i,j)    = v(end);                  % maior erro
    mAbs(i,j)  = mean(abs(e));
    dp(i,j)    = std(e);
    nEnt(i,j)  = n;
end

faltando = sum(isnan(media(:)));
if faltando > 0
    fprintf('ATENCAO: %d combinacao(oes) de frequencia e ruido sem arquivo; ficam em branco\n\n', faltando);
end

% tabela na tela
fprintf(['%7s | %5s | %8s | %16s | %16s | %16s\n'], 'rede', 'SNR', 'entalhes', ...
        sprintf('A) media (min a max) [%s]', unTxt), sprintf('B) media |e| [%s]', unTxt), ...
        sprintf('C) desvio [%s]', unTxt));
fprintf('%s\n', repmat('-', 1, 82));
for j = 1:nS
    for i = 1:nF
        if isnan(media(i,j)), continue; end
        fprintf('%7.2f | %5g | %8d | %+7.3f (%+5.2f a %+5.2f) | %16.3f | %16.3f\n', ...
                freqs(i), snrs(j), nEnt(i,j), media(i,j), mn(i,j), mx(i,j), mAbs(i,j), dp(i,j));
    end
end

%% ================= GRAFICO =================
cor = zeros(nS, 3);  auto = lines(max(nS, 1));
for j = 1:nS
    q = find(coresSNR(:,1) == snrs(j), 1);
    if isempty(q), cor(j,:) = auto(j,:); else, cor(j,:) = coresSNR(q, 2:4); end
end
rotulos = arrayfun(@(s) sprintf('%g dB', s), snrs, 'UniformOutput', false);

fig = figure('Color', 'w', 'Position', [80 60 900 1050], 'Name', ['Erro ' nome ' x frequencia']);
titulos = {sprintf('A)  Erro %s de cada entalhe: media (ponto) e do menor ao maior (barra)', nome), ...
           sprintf('B)  Media do valor absoluto do erro %s (tamanho tipico do erro)', nome), ...
           sprintf('C)  Desvio-padrao do erro %s (quanto o erro varia)', nome)};
valores = {media, mAbs, dp};
rotY    = {sprintf('erro %s [%s]', nome, unTxt), sprintf('|erro %s| [%s]', nome, unTxt), ...
           sprintf('desvio-padrao [%s]', unTxt)};

% AREA, painel B: a oscilacao da estimativa de frequencia amostra a amostra
% da SWRDFT (porSinal.rmsF).  A influencia da SWRDFT na area -- media do
% |area com a frequencia estimada - area com a verdadeira| -- vai so para a
% tabela na tela (arquivos gravados com influenciaFreq = true).
if strcmp(grandeza, 'area')
    temAF = all(arrayfun(@(d) isfield(d.erros, 'areaFreq') && ~isempty(d.erros.areaFreq), dados));
    if temAF
        infAbs = nan(nF, nS);  infMed = infAbs;  infMin = infAbs;  infMax = infAbs;
        for k = 1:numel(dados)
            i = find(abs(freqs - dados(k).f) < 1e-6);
            j = find(snrs == dados(k).snr);
            e = dados(k).erros.areaFreq(:);  e = e(isfinite(e));
            if isempty(e), continue; end
            infAbs(i,j) = mean(abs(e));  infMed(i,j) = mean(e);
            infMin(i,j) = min(e);        infMax(i,j) = max(e);
        end
        fprintf('\nINFLUENCIA DA FREQUENCIA ESTIMADA PELA SWRDFT NA AREA\n');
        fprintf('(area com a frequencia estimada - area com a frequencia verdadeira)\n');
        fprintf('%7s | %5s | %30s | %16s\n', 'rede', 'SNR', 'diferenca: media (min a max) [%]', 'media |dif| [%]');
        fprintf('%s\n', repmat('-', 1, 70));
        for j = 1:nS
            for i = 1:nF
                if isnan(infAbs(i,j)), continue; end
                fprintf('%7.2f | %5g | %+9.4f (%+8.4f a %+8.4f) | %16.4f\n', freqs(i), snrs(j), ...
                        infMed(i,j), infMin(i,j), infMax(i,j), infAbs(i,j));
            end
        end
    end
    % painel B: a oscilacao da estimativa de frequencia AMOSTRA A AMOSTRA da
    % SWRDFT, antes da media do registro (porSinal.rmsF) -- o efeito direto do
    % vazamento da janela, que cresce longe de 60 Hz ("U" centrado em 60 Hz)
    oscB = nan(nF, nS);
    for k = 1:numel(dados)
        if ~isfield(dados(k).porSinal, 'rmsF'), continue; end
        i = find(abs(freqs - dados(k).f) < 1e-6);
        j = find(snrs == dados(k).snr);
        o = dados(k).porSinal.rmsF(:);  o = o(isfinite(o));          % [Hz], um por sinal
        if ~isempty(o), oscB(i,j) = 1e3*mean(o); end
    end
    if any(~isnan(oscB(:)))
        valores{2} = oscB;
        titulos{2} = 'B)  Erro RMS da frequencia estimada pela SWRDFT amostra a amostra: RMS de f(i) - f real';
        rotY{2}    = 'erro RMS de f(i) [mHz]';
    else
        fprintf('\n(area, painel B: estes arquivos nao tem a oscilacao amostra a amostra\n');
        fprintf(' (porSinal.rmsF); o painel B mostra a media do |erro|.)\n');
    end
end
margemX = 0.3;

for pnl = 1:3
    ax = subplot(3, 1, pnl);
    hold(ax, 'on');
    hLinha = zeros(1, nS);
    if pnl == 1
        % barras de intervalo: do menor ao maior erro, ponto na media
        MED = media;  MN = mn;  MX = mx;
        passo = 1;  if nF > 1, passo = min(diff(freqs)); end
        dx = 0.22*passo;  cap = 0.06*passo;
        for j = 1:nS
            off = (j - (nS+1)/2)*dx;              % niveis de ruido lado a lado
            ok  = ~isnan(MED(:,j));
            for i = find(ok(:))'
                xx = freqs(i) + off;
                plot([xx xx], [MN(i,j) MX(i,j)], '-', 'Color', cor(j,:), 'LineWidth', 1.6);
                plot(xx + cap*[-1 1], MN(i,j)*[1 1], '-', 'Color', cor(j,:), 'LineWidth', 1.6);
                plot(xx + cap*[-1 1], MX(i,j)*[1 1], '-', 'Color', cor(j,:), 'LineWidth', 1.6);
            end
            hLinha(j) = plot(freqs(ok) + off, MED(ok,j), '-o', 'Color', cor(j,:), 'LineWidth', 1, ...
                             'MarkerSize', 6, 'MarkerFaceColor', cor(j,:), 'MarkerEdgeColor', 'w');
        end
    else
        % curvas (paineis B e C)
        V = valores{pnl};
        for j = 1:nS
            ok = ~isnan(V(:,j));
            hLinha(j) = plot(freqs(ok), V(ok,j), '-o', 'Color', cor(j,:), 'LineWidth', 2, ...
                             'MarkerSize', 6, 'MarkerFaceColor', cor(j,:), 'MarkerEdgeColor', 'w');
        end
    end
    % eixos
    xlim([min(freqs) - margemX, max(freqs) + margemX]);
    yl = ylim;
    if pnl == 3, yl(1) = 0; end
    yl = yl + [-0.05 0.05]*diff(yl);
    ylim(yl);
    plot([60 60], yl, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1);   % nominal
    if pnl == 1 && yl(1) < 0 && yl(2) > 0
        plot(xlim, [0 0], '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.8);
    end
    if nF <= 21
        set(ax, 'XTick', freqs);
    end
    grid(ax, 'on');  box(ax, 'on');
    set(ax, 'FontSize', 11, 'LineWidth', 0.8, 'Layer', 'top');
    ylabel(rotY{pnl}, 'FontSize', 12);
    title(titulos{pnl}, 'FontSize', 12, 'FontWeight', 'bold');
    if pnl == 3, xlabel('frequencia real da rede [Hz]', 'FontSize', 12); end
    legend(hLinha, rotulos, 'Location', 'northeastoutside', 'FontSize', 11);
end

condicoes = sprintf('%s  |  %d sinais por ponto (~%d entalhes)  |  regra %s  |  %s', ...
                    P0.harmonicasTexto, P0.nSinais, round(median(nEnt(~isnan(nEnt)))), ...
                    P0.regraDecisao, P0.programa);
if strcmp(grandeza, 'angulo')
    if strcmp(P0.refAngulo, 'fundamental')
        condicoes = [condicoes '  |  ref.: fundamental do sinal com entalhes'];
    else
        condicoes = [condicoes '  |  ref.: onda ideal'];
    end
end
try
    sgtitle({sprintf('Erro %s dos entalhes em funcao da frequencia da rede', nome), condicoes}, ...
            'FontSize', 12);
catch                                                               %#ok<CTCH>
    subplot(3, 1, 1);
    title({sprintf('Erro %s dos entalhes em funcao da frequencia da rede', nome), condicoes, ...
           titulos{1}}, 'FontSize', 11);
end

%% ================= GRAVAR =================
% nome com as condicoes fixas: harmonicas, sinais e sementeBase
H = P0.harmonicas;
if isempty(H)
    tagH = 'h0';
else
    partes = arrayfun(@(q) sprintf('%d-%s', H(q,1), strrep(sprintf('%g', 100*H(q,2)), '.', 'p')), ...
                      1:size(H,1), 'UniformOutput', false);
    tagH = ['h' strjoin(partes, '_')];
end
tag = sprintf('erro_%s_%s_n%d_s%d', tagG, tagH, P0.nSinais, P0.sementeBase);
if strcmp(P0.refAngulo, 'fundamental'), tag = [tag '_reffund']; end
if ~isempty(snrsPlotar)                  % so alguns niveis: sufixo no nome
    tag = [tag '_snr' strjoin(arrayfun(@(v) sprintf('%g', v), unique([dados.snr]), ...
                                       'UniformOutput', false), '-')];
end
pastaG = fullfile(pasta, 'graficos');
if ~exist(pastaG, 'dir'), mkdir(pastaG); end

if gravarFiguras
print(fig, fullfile(pastaG, [tag '.png']), '-dpng', '-r200');
if exist('savefig', 'file') && ~exist('OCTAVE_VERSION', 'builtin')
    savefig(fig, fullfile(pastaG, [tag '.fig']));
end
pontos = struct('grandeza', grandeza, 'unidade', un, 'freqs', freqs, 'snrs', snrs, ...
                'media', media, 'minimo', mn, 'maximo', mx, 'mediaAbs', mAbs, 'desvio', dp, ...
                'entalhes', nEnt, 'arquivos', {{dados.arquivo}});
condicoesFixas = P0;
save(fullfile(pastaG, [tag '.mat']), 'pontos', 'condicoesFixas', '-v7');
fprintf('\nGrafico gravado em %s/graficos/%s.png\n', pastaResultados, tag);
fprintf('Valores de cada ponto em %s/graficos/%s.mat (variavel pontos)\n', pastaResultados, tag);
end
end
dados = dadosLidos;

%% ================= 4. FIGURA 3: FREQUENCIA =================
%% --------- frequencia: calcular os pontos ---------
freqs = unique(round([dados.f]*1000)/1000);
snrs  = sort(unique([dados.snr]));
nF = numel(freqs);  nS = numel(snrs);
fMed = nan(nF, nS);  fMin = fMed;  fMax = fMed;  nSin = fMed;     % [mHz]
oscMed = nan(nF, nS);    % oscilacao RMS da estimativa amostra a amostra [mHz]

for k = 1:numel(dados)
    i = find(abs(freqs - dados(k).f) < 1e-6);
    j = find(snrs == dados(k).snr);
    e = dados(k).porSinal.erroF(:);  e = e(isfinite(e));    % [Hz], um por sinal
    if isempty(e), continue; end
    fMed(i,j) = 1e3*mean(e);          % erro medio dos sinais [mHz]
    fMin(i,j) = 1e3*min(e);           % menor erro [mHz]
    fMax(i,j) = 1e3*max(e);           % maior erro [mHz]
    nSin(i,j) = numel(e);
    if isfield(dados(k).porSinal, 'rmsF')
        o = dados(k).porSinal.rmsF(:);  o = o(isfinite(o));         % [Hz], um por sinal
        if ~isempty(o), oscMed(i,j) = 1e3*mean(o); end
    end
end
temOsc = false;     % a oscilacao vai para o painel B do grafico da AREA

faltando = sum(isnan(fMed(:)));
if faltando > 0
    fprintf('ATENCAO: %d combinacao(oes) de frequencia e ruido sem arquivo; ficam em branco\n\n', faltando);
end

% tabela na tela
fprintf('%7s | %5s | %6s | %16s | %16s | %16s | %16s\n', 'rede', 'SNR', 'sinais', ...
        'erro medio [mHz]', 'menor erro [mHz]', 'maior erro [mHz]', 'oscilacao [mHz]');
fprintf('%s\n', repmat('-', 1, 72));
for j = 1:nS
    for i = 1:nF
        if isnan(fMed(i,j)), continue; end
        fprintf('%7.2f | %5g | %6d | %+16.4f | %+16.4f | %+16.4f | %16.3f\n', freqs(i), snrs(j), ...
                nSin(i,j), fMed(i,j), fMin(i,j), fMax(i,j), oscMed(i,j));
    end
end

%% --------- frequencia: grafico ---------
cor = zeros(nS, 3);  auto = lines(max(nS, 1));
for j = 1:nS
    q = find(coresSNR(:,1) == snrs(j), 1);
    if isempty(q), cor(j,:) = auto(j,:); else, cor(j,:) = coresSNR(q, 2:4); end
end
rotulos = arrayfun(@(s) sprintf('%g dB', s), snrs, 'UniformOutput', false);

if temOsc       % dois paineis: A) erro da media do registro; B) oscilacao amostra a amostra
    fig = figure('Color', 'w', 'Position', [80 60 950 900], 'Name', 'Erro da frequencia estimada');
    ax = subplot(2, 1, 1);
else            % arquivos sem a oscilacao gravada: so o painel A
    fig = figure('Color', 'w', 'Position', [80 80 950 560], 'Name', 'Erro da frequencia estimada');
    ax = axes('Parent', fig);
end
hold(ax, 'on');
hLinha = zeros(1, nS);
% barras de intervalo: do menor ao maior erro dos sinais, ponto na media
MED = fMed;  MN = fMin;  MX = fMax;
passo = 1;  if nF > 1, passo = min(diff(freqs)); end
dx = 0.22*passo;  cap = 0.06*passo;
for j = 1:nS
    off = (j - (nS+1)/2)*dx;              % niveis de ruido lado a lado
    ok  = ~isnan(MED(:,j));
    for i = find(ok(:))'
        xx = freqs(i) + off;
        plot([xx xx], [MN(i,j) MX(i,j)], '-', 'Color', cor(j,:), 'LineWidth', 1.6);
        plot(xx + cap*[-1 1], MN(i,j)*[1 1], '-', 'Color', cor(j,:), 'LineWidth', 1.6);
        plot(xx + cap*[-1 1], MX(i,j)*[1 1], '-', 'Color', cor(j,:), 'LineWidth', 1.6);
    end
    hLinha(j) = plot(freqs(ok) + off, MED(ok,j), '-o', 'Color', cor(j,:), 'LineWidth', 1, ...
                     'MarkerSize', 6, 'MarkerFaceColor', cor(j,:), 'MarkerEdgeColor', 'w');
end

% eixo X: uma marca para cada frequencia (ate 21); acima disso, a cada 1 Hz
margemX = 0.3;
xlim([min(freqs) - margemX, max(freqs) + margemX]);
if nF <= 21
    set(ax, 'XTick', freqs);
else
    set(ax, 'XTick', ceil(min(freqs)):1:floor(max(freqs)));
end
yl = ylim;  yl = yl + [-0.06 0.06]*diff(yl);  ylim(yl);
plot(xlim, [0 0], '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.8);       % erro zero
plot([60 60], yl, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1);       % nominal

grid(ax, 'on');  box(ax, 'on');
set(ax, 'FontSize', 11, 'LineWidth', 0.8);
if ~temOsc, xlabel('frequencia real da rede [Hz]', 'FontSize', 12); end
ylabel('erro da frequencia estimada [mHz]', 'FontSize', 12);
tituloA = 'Frequencia estimada pela cadeia: erro de cada sinal, media (ponto) e do menor ao maior (barra)';
if temOsc, tituloA = ['A)  ' tituloA]; end
title({tituloA, ...
       sprintf('%s  |  %d sinais por ponto  |  regra %s  |  %s', P0.harmonicasTexto, ...
               P0.nSinais, P0.regraDecisao, P0.programa)}, 'FontSize', 12);
legend(hLinha, rotulos, 'Location', 'northeastoutside', 'FontSize', 11);

% painel B: oscilacao da estimativa AMOSTRA A AMOSTRA da SWRDFT, antes da
% media do registro -- o efeito direto do vazamento da janela, sem os
% cancelamentos da media (forma um "U" centrado em 60 Hz)
if temOsc
    ax = subplot(2, 1, 2);
    hold(ax, 'on');
    hLinhaB = zeros(1, nS);
    for j = 1:nS
        ok = ~isnan(oscMed(:,j));
        hLinhaB(j) = plot(freqs(ok), oscMed(ok,j), '-o', 'Color', cor(j,:), 'LineWidth', 2, ...
                          'MarkerSize', 6, 'MarkerFaceColor', cor(j,:), 'MarkerEdgeColor', 'w');
    end
    xlim([min(freqs) - margemX, max(freqs) + margemX]);
    if nF <= 21
        set(ax, 'XTick', freqs);
    else
        set(ax, 'XTick', ceil(min(freqs)):1:floor(max(freqs)));
    end
    yl = ylim;  yl(1) = 0;  yl(2) = 1.08*yl(2);  ylim(yl);
    plot([60 60], yl, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1);   % nominal
    grid(ax, 'on');  box(ax, 'on');
    set(ax, 'FontSize', 11, 'LineWidth', 0.8);
    xlabel('frequencia real da rede [Hz]', 'FontSize', 12);
    ylabel('oscilacao RMS de f(i) [mHz]', 'FontSize', 12);
    title('B)  Estimativa da SWRDFT amostra a amostra, antes da media: oscilacao RMS em torno da f real', ...
          'FontSize', 12);
    legend(hLinhaB, rotulos, 'Location', 'northeastoutside', 'FontSize', 11);
end

%% --------- frequencia: gravar ---------
H = P0.harmonicas;
if isempty(H)
    tagH = 'h0';
else
    partes = arrayfun(@(q) sprintf('%d-%s', H(q,1), strrep(sprintf('%g', 100*H(q,2)), '.', 'p')), ...
                      1:size(H,1), 'UniformOutput', false);
    tagH = ['h' strjoin(partes, '_')];
end
tag = sprintf('erro_frequencia_%s_n%d_s%d', tagH, P0.nSinais, P0.sementeBase);
if strcmp(P0.refAngulo, 'fundamental'), tag = [tag '_reffund']; end
if ~isempty(snrsPlotar)                  % so alguns niveis: sufixo no nome
    tag = [tag '_snr' strjoin(arrayfun(@(v) sprintf('%g', v), unique([dados.snr]), ...
                                       'UniformOutput', false), '-')];
end
pastaG = fullfile(pasta, 'graficos');
if ~exist(pastaG, 'dir'), mkdir(pastaG); end

if gravarFiguras
print(fig, fullfile(pastaG, [tag '.png']), '-dpng', '-r200');
if exist('savefig', 'file') && ~exist('OCTAVE_VERSION', 'builtin')
    savefig(fig, fullfile(pastaG, [tag '.fig']));
end
pontos = struct('freqs', freqs, 'snrs', snrs, 'erroMedio_mHz', fMed, 'erroMin_mHz', fMin, ...
                'erroMax_mHz', fMax, 'oscilacao_mHz', oscMed, 'sinais', nSin, ...
                'arquivos', {{dados.arquivo}});
condicoesFixas = P0;
save(fullfile(pastaG, [tag '.mat']), 'pontos', 'condicoesFixas', '-v7');
fprintf('\nGrafico gravado em %s/graficos/%s.png\n', pastaResultados, tag);
fprintf('Valores de cada ponto em %s/graficos/%s.mat (variavel pontos)\n', pastaResultados, tag);
end
