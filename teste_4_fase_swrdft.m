%% TESTE 4 - FASE DO ENTALHE PELA SWRDFT, COM A REDE FORA DE 60 Hz
%
% Quarto degrau da escada de escalabilidade.
%
% PERGUNTA
%   Com a frequencia da rede diferente de 60 Hz, conseguimos medir em que
%   ponto da onda (angulo eletrico) cada entalhe ocorre?
%
% POR QUE ISSO E UM PROBLEMA
%   O notch_analyze calcula o angulo de cada entalhe como
%       angulo = 360 * f0 * t + fase inicial
%   com f0 = 60 Hz fixo.  Se a rede esta em 60,1 Hz, o erro cresce com o
%   tempo: 360 * 0,1 * t.  Em 0,2 s isso ja da 7 graus; em 1 minuto, 2160.
%
% METODO
%   A SWRDFT (SWRDFT.m) calcula a fase da fundamental a cada amostra.
%   A partir dela, fase_swrdft.m obtem a frequencia real e a fase
%   instantanea, ja corrigida do atraso de meio ciclo da janela.  O angulo
%   de cada entalhe e a fase instantanea no centro do entalhe.
%
%   O sinal e o dos testes anteriores, com ruido de 55 dB e 4 % de THD,
%   e com a frequencia da rede variando de -2 a +2 Hz em torno de 60 Hz.
%   A deteccao e feita pela cadeia (notch_analyze), que fornece o centro
%   de cada entalhe.  O angulo tem duas fontes de erro, avaliadas
%   separadamente: a LEITURA da fase pela SWRDFT (Tabela 2, comparando no
%   mesmo instante) e a LOCALIZACAO do entalhe pelo detector (Tabela 2B,
%   comparando o centro detectado com o verdadeiro).  A Tabela 2B traz
%   tambem o erro total, a soma das duas.  Desde a integracao da SWRDFT a cadeia, o
%   notch_analyze tambem estima a frequencia real e ressintoniza o
%   detector com ela.  Este teste avalia a medicao da frequencia e do
%   angulo pela SWRDFT.
%
% ANGULO VERDADEIRO
%   O gerador usa e_a = Vp*sin(w*t) e e_b = Vp*sin(w*t - 120), logo
%   v_ab = sqrt(3)*Vp*sin(w*t + 30 graus).  O angulo verdadeiro num
%   instante t e 360*f_real*t + 30, modulo 360.
%
% ARQUIVOS NECESSARIOS (todos nesta pasta)
%   gerar_sinal_teste.m, notch_analyze.m, notch_detector.m,
%   SWRDFT.m, fase_swrdft.m, difang.m, plot_ciclo_fase.m,
%   descrever_sinal.m, harmonicos_thd.m, sinal_bloco.m, swrdft_bloco.m,
%   plot_erro_frequencia.m, plot_erro_fase.m
%
% REGISTRO LONGO (secao 4)
%   A secao 4 simula um registro de minutos.  A duracao fica na variavel
%   duracaoLonga, no inicio da secao (padrao: 600 s = 10 min).
%
% VARREDURA DE FREQUENCIA (secao 5)
%   A secao 5 mede o erro com a rede de 55 a 65 Hz, para saber ate onde o
%   metodo funciona.  Faixa, passo e criterio ficam no inicio da secao.

clear; close all; clc;

%% ================= 1. SINAL TESTADO =================
Fs       = 62.5e3;
f0       = 60;                 % frequencia NOMINAL, a que a cadeia supoe
nCiclos  = 12;
Vll      = 480;
alphaDeg = 35;
muDeg    = 9;
Ls       = 30e-6;
Lt       = 70e-6;
snr      = 55;                 % ruido [dB], aprovado no teste 2
thd      = 0.04;               % distorcao harmonica, aprovada no teste 3

sinal = {'Modo', 'conversor', 'Fs', Fs, 'f0', f0, 'nCiclos', nCiclos, ...
         'Vll', Vll, 'Grandeza', 'fase-fase', ...
         'alphaDeg', alphaDeg, 'muDeg', muDeg, 'Ls', Ls, 'Lt', Lt, ...
         'Bits', [], 'SNRdb', snr, 'Harmonicos', harmonicos_thd(thd)};

% O que este teste acrescenta: a rede fora de 60 Hz.
desvios = [-2 -1 -0.5 0 0.5 1 2];          % [Hz]

% Exemplo do sinal com a rede em 60,5 Hz, so para visualizacao
[x, t, truth, meta] = gerar_sinal_teste(sinal{:}, 'DesvioFreqHz', 0.5, 'Semente', 1);
xRef = gerar_sinal_teste(sinal{:}, 'DesvioFreqHz', 0.5, 'Semente', 1, ...
                         'Ls', 0, 'SNRdb', []);
descrever_sinal(x, t, truth, meta, 'rede em 60,5 Hz, ruido 55 dB, THD 4 %', xRef);
fprintf('  frequencia real da rede ... %.1f Hz  (a cadeia supoe %g Hz)\n', ...
        meta.fReal, f0);

%% ================= 2. AVALIACAO =================
sementes = [1 2 3];
resultados = struct('df', {}, 'fReal', {}, 'fEst', {}, 'nAval', {}, ...
                    'nFora', {}, 'erroAng', {}, 'deslocAm', {}, ...
                    'erroTot', {}, 'nSemPar', {});

for df = desvios
    fEst = [];  erroAng = [];  nFora = 0;
    deslocAm = [];  erroTot = [];  nSemPar = 0;
    for s = sementes
        [x, ~, truth, meta] = gerar_sinal_teste(sinal{:}, 'DesvioFreqHz', df, 'Semente', s);

        % deteccao pela cadeia: fornece o centro de cada entalhe
        R  = notch_analyze(x, Fs, f0, 'Vll', Vll);
        ev = R.eventos(~[R.eventos.modeloReduzido]);
        tc = 0.5*([ev.tInicio] + [ev.tFim]);
        ic = round(tc*Fs) + 1;

        % frequencia e fase instantanea pela SWRDFT
        F  = fase_swrdft(x, Fs, f0);
        ok = F.valido(ic)';                       % so apos duas janelas
        nFora = nFora + sum(~ok);
        fEst  = [fEst; F.f(F.valido)];            %#ok<AGROW>

        % ERRO DE LEITURA DA FASE: angulo medido pela SWRDFT x angulo
        % verdadeiro NO MESMO INSTANTE (o centro detectado)
        angMedido = mod(rad2deg(F.theta(ic(ok))'), 360);
        angVerd   = mod(360*meta.fReal*tc(ok) + 30, 360);
        erroAng   = [erroAng, difang(angMedido, angVerd)];   %#ok<AGROW>

        % ERRO DE LOCALIZACAO E ERRO TOTAL: cada entalhe detectado e
        % associado ao entalhe verdadeiro mais proximo (ate 1,5 ms)
        ent  = truth(strcmp({truth.tipo}, 'entalhe'));
        tv   = 0.5*([ent.tInicio] + [ent.tFim]);         % centros verdadeiros
        tcOk = tc(ok);
        for k = 1:numel(tcOk)
            [dist, j] = min(abs(tv - tcOk(k)));
            if dist <= 1.5e-3
                % centro detectado - centro verdadeiro, em amostras
                deslocAm(end+1) = (tcOk(k) - tv(j))*Fs;            %#ok<AGROW>
                % angulo medido x angulo verdadeiro NO CENTRO VERDADEIRO
                angCentro = mod(360*meta.fReal*tv(j) + 30, 360);
                erroTot(end+1) = difang(angMedido(k), angCentro);  %#ok<AGROW>
            else
                nSemPar = nSemPar + 1;      % evento sem entalhe verdadeiro perto
            end
        end
    end
    resultados(end+1) = struct('df', df, 'fReal', 60 + df, 'fEst', fEst, ...
                               'nAval', numel(erroAng), 'nFora', nFora, ...
                               'erroAng', erroAng, 'deslocAm', deslocAm, ...
                               'erroTot', erroTot, 'nSemPar', nSemPar);   %#ok<SAGROW>
end

%% ================= 3. RESULTADO =================
linhaSep = repmat('-', 1, 78);

% ---------- tabela 1: frequencia ----------
fprintf('\nTABELA 1 - FREQUENCIA DA REDE MEDIDA PELA SWRDFT\n');
fprintf('%s\n', linhaSep);
fprintf('%8s | %9s | %12s | %10s | %10s | %12s\n', 'desvio', 'f real', ...
        'f estimada', 'erro', 'oscilacao', 'pior amostra');
fprintf('%8s | %9s | %12s | %10s | %10s | %12s\n', '[Hz]', '[Hz]', ...
        '(media) [Hz]', '[Hz]', '[Hz]', '[Hz]');
fprintf('%s\n', linhaSep);
for r = resultados
    e = r.fEst - r.fReal;
    fprintf('%+8.1f | %9.3f | %12.4f | %+10.5f | %10.4f | %12.4f\n', ...
            r.df, r.fReal, mean(r.fEst), mean(e), std(r.fEst), max(abs(e)));
end
fprintf('%s\n', linhaSep);
fprintf('erro ......... media das estimativas menos a frequencia real\n');
fprintf('oscilacao .... desvio-padrao da estimativa de amostra para amostra\n');
fprintf('pior amostra . maior erro de uma amostra isolada\n');

% ---------- tabela 2: angulo ----------
fprintf('\nTABELA 2 - ANGULO DE CADA ENTALHE NA ONDA, MEDIDO PELA SWRDFT\n');
fprintf('%s\n', linhaSep);
fprintf('%8s | %9s | %9s | %10s | %10s | %8s | %9s\n', 'desvio', 'entalhes', ...
        'fora', 'erro medio', 'desvio-', 'P90', 'pior');
fprintf('%8s | %9s | %9s | %10s | %10s | %8s | %9s\n', '[Hz]', 'avaliados', ...
        '(aquec.)', '[graus]', 'padrao [g]', '[graus]', 'caso [g]');
fprintf('%s\n', linhaSep);
for r = resultados
    e = r.erroAng;
    d = sort(abs(e - mean(e)));
    p90 = d(max(1, ceil(0.9*numel(d))));
    fprintf('%+8.1f | %9d | %9d | %+10.2f | %10.2f | %8.2f | %9.2f\n', ...
            r.df, r.nAval, r.nFora, mean(e), std(e), p90, max(abs(e)));
end
fprintf('%s\n', linhaSep);
fprintf('entalhes avaliados .. somados nas %d sementes\n', numel(sementes));
fprintf('fora (aquec.) ....... entalhes das duas primeiras janelas da SWRDFT,\n');
fprintf('                      quando a frequencia ainda nao existe\n');
fprintf('erro medio .......... deslocamento constante (ver abaixo)\n');
fprintf('desvio-padrao ....... variacao do erro de um entalhe para outro\n');
fprintf('P90 ................. 90 %% dos entalhes ficam a menos disso do erro medio\n');
fprintf('pior caso ........... maior erro absoluto entre todos os entalhes\n');

% ---------- tabela 2B: localizacao e erro total ----------
sepB = repmat('-', 1, 90);
fprintf('\nTABELA 2B - LOCALIZACAO DOS ENTALHES E ERRO TOTAL DO ANGULO\n');
fprintf('%s\n', sepB);
fprintf('%7s | %8s | %7s | %28s | %26s\n', 'desvio', 'entalhes', 'sem', ...
        'localizacao do centro', 'erro total do angulo');
fprintf('%7s | %8s | %7s | %9s %8s %9s | %8s %7s %9s\n', '[Hz]', 'pareados', 'par', ...
        'medio[am]', 'pior[am]', 'pior[g]', 'medio[g]', 'RMS[g]', 'pior[g]');
fprintf('%s\n', sepB);
for r = resultados
    d = r.deslocAm;  e = r.erroTot;
    grausPorAmostra = 360*r.fReal/Fs;
    fprintf('%+7.1f | %8d | %7d | %+9.2f %8.2f %9.2f | %+8.2f %7.2f %9.2f\n', ...
            r.df, numel(d), r.nSemPar, mean(d), max(abs(d)), ...
            max(abs(d))*grausPorAmostra, mean(e), sqrt(mean(e.^2)), max(abs(e)));
end
fprintf('%s\n', sepB);
fprintf('localizacao ..... centro detectado menos centro verdadeiro, em amostras\n');
fprintf('                  (am) e em graus (g): cada amostra vale 360*f/Fs,\n');
fprintf('                  cerca de 0,35 grau a 60 Hz e 62,5 kS/s.  Positivo =\n');
fprintf('                  detectado depois do verdadeiro\n');
fprintf('erro total ...... angulo medido no centro DETECTADO menos o angulo\n');
fprintf('                  verdadeiro no centro VERDADEIRO = erro de leitura da\n');
fprintf('                  fase (Tabela 2) + erro de localizacao.  E o erro que\n');
fprintf('                  um usuario veria num sinal real\n');
fprintf('sem par ......... eventos sem entalhe verdadeiro a ate 1,5 ms\n');

% ---------- resumo ----------
todos = [resultados.erroAng];
fprintf('\nRESUMO\n');
fprintf('  frequencia: erro medio de no maximo %.4f Hz em toda a faixa\n', ...
        max(arrayfun(@(r) abs(mean(r.fEst) - r.fReal), resultados)));
fprintf('  angulo: erro medio entre %+.2f e %+.2f graus; pior caso %.2f graus\n', ...
        min(arrayfun(@(r) mean(r.erroAng), resultados)), ...
        max(arrayfun(@(r) mean(r.erroAng), resultados)), max(abs(todos)));
desl = [resultados.deslocAm];  tot = [resultados.erroTot];
fprintf('  localizacao: pior deslocamento de %.2f amostras em toda a faixa\n', max(abs(desl)));
fprintf('  erro total do angulo: RMS de %.2f graus, pior caso %.2f graus\n', ...
        sqrt(mean(tot.^2)), max(abs(tot)));
fprintf('\nO ERRO MEDIO DE CERCA DE -1 GRAU\n');
fprintf('  E constante em toda a faixa e nao e falha do metodo: os entalhes\n');
fprintf('  deslocam a fase da propria fundamental da tensao medida, e o angulo\n');
fprintf('  sai referido a ela, nao a fonte ideal por tras dela.\n');

%% ================= 4. REGISTRO LONGO: O ERRO ACUMULA? =================
% Os registros acima tem 0,2 s -- curtos demais para revelar um erro que
% cresce devagar.  Aqui o registro pode ter MINUTOS.
%
% A duracao e configuravel em duracaoLonga.  Para caber na memoria, o
% sinal e gerado e processado em BLOCOS de blocoS segundos
% (sinal_bloco.m e swrdft_bloco.m); o estado da SWRDFT passa de um bloco
% para o seguinte, exatamente como num registro continuo.
%
% Em cada entalhe, compara-se o angulo medido pela SWRDFT com o angulo
% verdadeiro da fundamental NO MESMO INSTANTE.  Usa-se o centro VERDADEIRO
% de cada entalhe, dado pelo modelo do conversor: a deteccao fica de fora
% desta secao porque e lenta em registros longos e nao depende do tamanho
% do registro (cada entalhe e tratado a partir do meio ciclo anterior).
%
% TEMPO DE EXECUCAO: no GNU Octave, cerca de 1,2 s de processamento por
% segundo de sinal (10 min -> ~12 min).  No MATLAB costuma ser bem menor.

rodarLongo   = true;     % false para pular esta secao
duracaoLonga = 600;      % [s] 10 minutos -- altere a vontade (ex.: 180)
desvioLongo  = 0.5;      % [Hz] desvio da rede em relacao a 60 Hz
blocoS       = 20;       % [s] tamanho de cada bloco

% ---------- parametros comuns as secoes 4 e 5 ----------
p = struct('Vll', Vll, 'fReal', f0 + desvioLongo, 'alphaDeg', alphaDeg, ...
           'muDeg', muDeg, 'Ls', Ls, 'Lt', Lt, 'H', harmonicos_thd(thd));
N  = round(Fs/f0);
w0 = 2*pi/N;
w  = 2*pi*p.fReal;

% ---------- conferencia das funcoes de bloco ----------
% As secoes 4 e 5 usam sinal_bloco.m e swrdft_bloco.m.  Antes de confiar
% nelas, confere que reproduzem gerar_sinal_teste e SWRDFT.m num trecho
% curto.  Roda sempre, mesmo com as secoes 4 e 5 desligadas (leva ~2 s).
[xc, tcur] = gerar_sinal_teste(sinal{:}, 'SNRdb', [], 'DesvioFreqHz', desvioLongo);
xb  = [sinal_bloco(tcur(1:4000), p); sinal_bloco(tcur(4001:end), p)];
[~, PhRef] = SWRDFT(xc, f0, N, 1);
estC = struct('Nppc', N, 's1', 0, 's2', 1, 'Yc', 0, 'Ys', 0, 'buf', zeros(N,1), 'n', 0);
[Pa, estC] = swrdft_bloco(xc(1:5000), estC);
[Pb, estC] = swrdft_bloco(xc(5001:end), estC);
dSinal = max(abs(xb - xc));
dFase  = max(abs([Pa; Pb] - PhRef(:,2)));
fprintf('\nCONFERENCIA DAS FUNCOES DE BLOCO\n');
fprintf('  sinal_bloco  x gerar_sinal_teste ... diferenca maxima %.1e V\n', dSinal);
fprintf('  swrdft_bloco x SWRDFT.m ............ diferenca maxima %.1e rad\n', dFase);
if dSinal > 1e-6 || dFase > 1e-9
    warning('teste4:conferencia', ...
            'As funcoes de bloco nao reproduzem as originais; resultado nao confiavel.');
end

if rodarLongo

    % ---------- preparacao ----------
    B       = round(blocoS*Fs);
    nTotal  = round(duracaoLonga*Fs);
    nBlocos = ceil(nTotal/B);
    t1      = (0:B-1)'/Fs;
    sigma   = sqrt(mean(sinal_bloco(t1, p).^2)/10^(snr/10));   % ruido do SNR pedido

    est    = struct('Nppc', N, 's1', 0, 's2', 1, 'Yc', 0, 'Ys', 0, 'buf', zeros(N,1), 'n', 0);
    PhPrev = nan(N, 1);
    nMax   = ceil(duracaoLonga*p.fReal*6) + 12;   % entalhes esperados (pre-alocacao)
    tE     = zeros(nMax, 1);   tipoE = zeros(nMax, 1);
    verdE  = zeros(nMax, 1);   erroE = zeros(nMax, 1);
    cnt    = 0;
    fBloco = nan(nBlocos, 2);                      % media e oscilacao por bloco
    alpha  = alphaDeg*pi/180;   mu = muDeg*pi/180;

    if nBlocos == 1, txtB = 'bloco'; else, txtB = 'blocos'; end
    fprintf('\nREGISTRO LONGO: %.0f s (%.1f min) em %d %s de %g s, rede em %.2f Hz\n', ...
            duracaoLonga, duracaoLonga/60, nBlocos, txtB, blocoS, p.fReal);

    % ---------- processamento bloco a bloco ----------
    for k = 1:nBlocos
        ig0 = (k-1)*B;                             % indice global da 1a amostra (base 0)
        nb  = min(B, nTotal - ig0);
        tb  = (ig0:ig0+nb-1)'/Fs;

        try, rng(1000 + k); catch, randn('seed', 1000 + k); end   %#ok<RAND>
        xbl = sinal_bloco(tb, p) + sigma*randn(nb, 1);

        [Ph, est] = swrdft_bloco(xbl, est);

        % frequencia: diferenca de fase sobre exatamente uma janela
        PhA  = [PhPrev; Ph];
        dphi = mod(PhA(N+1:end) - PhA(1:nb) + pi, 2*pi) - pi;
        f    = Fs/N + dphi*Fs/(2*pi*N);
        ig   = (ig0+1:ig0+nb)';                    % indice global (base 1)
        f(ig <= 2*N) = NaN;                        % so apos duas janelas
        fv = f(~isnan(f));
        if ~isempty(fv), fBloco(k,:) = [mean(fv), std(fv)]; end

        % centros verdadeiros dos entalhes neste bloco
        c0 = max(0, floor(w*tb(1)/(2*pi)));
        c1 = ceil(w*tb(end)/(2*pi));
        for cyc = c0:c1
            for r = 0:5
                tcv = ((30 + 60*r)*pi/180 + alpha + mu/2 + 2*pi*cyc)/w;
                j = round(tcv*Fs) + 1 - ig0;       % posicao no bloco
                if j < 1 || j > nb || isnan(f(j)), continue; end
                th  = w0*ig(j) + Ph(j) + (2*pi*f(j)/Fs - w0)*(N - 1)/2;
                thv = w*((ig(j) - 1)/Fs) + pi/6;   % v_ab = sqrt(3)Vp sin(wt + 30)
                cnt = cnt + 1;
                tE(cnt)    = (ig(j) - 1)/Fs;
                tipoE(cnt) = r;
                verdE(cnt) = mod(rad2deg(thv), 360);
                erroE(cnt) = rad2deg(mod(th - thv + pi, 2*pi) - pi);
            end
        end
        PhPrev = Ph(end-N+1:end);
        fprintf('  bloco %3d de %d  (%5.0f s de %.0f s)\n', k, nBlocos, (ig0 + nb)/Fs, duracaoLonga);
    end
    tE = tE(1:cnt);  tipoE = tipoE(1:cnt);  verdE = verdE(1:cnt);  erroE = erroE(1:cnt);

    % ---------- tabela 3: o erro ao longo do tempo ----------
    nFat = 10;
    bordas = linspace(0, duracaoLonga, nFat + 1);
    fprintf('\nTABELA 3 - ERRO DO ANGULO AO LONGO DO REGISTRO (%d entalhes)\n', cnt);
    fprintf('%s\n', linhaSep);
    fprintf('%17s | %9s | %10s | %10s | %9s\n', 'trecho', 'entalhes', ...
            'erro medio', 'desvio-', 'pior');
    fprintf('%17s | %9s | %10s | %10s | %9s\n', '[s]', '', ...
            '[graus]', 'padrao [g]', 'caso [g]');
    fprintf('%s\n', linhaSep);
    for q = 1:nFat
        m = tE >= bordas(q) & tE < bordas(q+1);
        if ~any(m), continue; end
        fprintf('%7.0f a %7.0f | %9d | %+10.3f | %10.3f | %9.2f\n', bordas(q), bordas(q+1), ...
                sum(m), mean(erroE(m)), std(erroE(m)), max(abs(erroE(m))));
    end
    fprintf('%s\n', linhaSep);

    pL  = polyfit(tE, erroE, 1);
    epL = std(erroE - polyval(pL, tE))/(sqrt(cnt)*std(tE));
    fprintf('tendencia ao longo do registro ... %+.6f +/- %.6f graus por segundo\n', pL(1), epL);
    fprintf('variacao da tendencia no registro  %+.4f graus\n', pL(1)*duracaoLonga);
    if abs(pL(1)) < 2*epL
        fprintf('  -> compativel com zero: o erro NAO acumula\n');
    else
        fprintf('  -> diferente de zero: verificar\n');
    end

    % ---------- tabela 4: por tipo de entalhe, inicio x fim ----------
    mIni = tE <  bordas(2);
    mFim = tE >= bordas(end-1);
    fprintf('\nTABELA 4 - ERRO POR TIPO DE ENTALHE: PRIMEIRO x ULTIMO TRECHO\n');
    fprintf('%s\n', linhaSep);
    fprintf('%14s | %15s | %15s | %12s\n', 'angulo [graus]', 'inicio [graus]', ...
            'fim [graus]', 'diferenca [g]');
    fprintf('%s\n', linhaSep);
    for r = 0:5
        a = tipoE == r & mIni;  b = tipoE == r & mFim;
        if ~any(a) || ~any(b), continue; end
        fprintf('%14.1f | %+15.3f | %+15.3f | %+12.4f\n', median(verdE(tipoE == r)), ...
                mean(erroE(a)), mean(erroE(b)), mean(erroE(b)) - mean(erroE(a)));
    end
    fprintf('%s\n', linhaSep);

    ok = ~isnan(fBloco(:,1));
    fprintf('\nfrequencia (media de todas as amostras de cada bloco):\n');
    fprintf('  primeiro bloco %+.5f Hz | ultimo bloco %+.5f Hz | maior erro %.5f Hz\n', ...
            fBloco(find(ok,1),1) - p.fReal, fBloco(find(ok,1,'last'),1) - p.fReal, ...
            max(abs(fBloco(ok,1) - p.fReal)));

    fprintf('\nCOMO LER\n');
    fprintf('  Erro = angulo medido pela SWRDFT menos o angulo da fundamental\n');
    fprintf('  verdadeira no mesmo instante.  Se ele acumulasse, os trechos finais\n');
    fprintf('  da Tabela 3 teriam erro maior que os iniciais, e a Tabela 4 mostraria\n');
    fprintf('  diferencas crescentes.  Cada tipo de entalhe tem um erro proprio e\n');
    fprintf('  fixo: e o vazamento da janela da SWRDFT, lido sempre no mesmo ponto\n');
    fprintf('  da onda porque cada entalhe ocorre sempre no mesmo angulo.\n');

    try
        plot_ciclo_fase(tE, verdE + erroE, verdE, ...
            sprintf('Teste 4 - %.1f min com a rede em %.2f Hz', duracaoLonga/60, p.fReal));
    catch err
        fprintf('\n(grafico nao exibido: %s)\n', err.message);
    end
else
    fprintf('\n(secao 4, registro longo, pulada: rodarLongo = false)\n');
    tE = []; tipoE = []; verdE = []; erroE = [];
end

%% ================= 5. ERRO EM FUNCAO DA FREQUENCIA DA REDE =================
% Ate que desvio de frequencia o metodo funciona?
%
% A frequencia real da rede varia de faixaFreq(1) a faixaFreq(2), em
% passos de passoFreq.  Em cada uma, um registro de duracaoPonto segundos
% e analisado: o angulo de cada entalhe (lido no centro VERDADEIRO, como
% na secao 4) e a frequencia estimada pela SWRDFT.
%
% COMO SE DECIDE "ATE ONDE FUNCIONA"
%   O erro medio do angulo quase nao muda com a frequencia.  O que cresce e
%   a DISPERSAO entre entalhes, causada pelo vazamento da janela da SWRDFT,
%   que tem o tamanho de um ciclo de 60 Hz: quanto mais a rede foge de
%   60 Hz, menos a janela fecha um ciclo real.  O criterio e o PIOR erro
%   absoluto entre todos os entalhes: o metodo funciona onde ele fica
%   dentro de limiteErro.  Ajuste o limite a exigencia da sua aplicacao.
%
% TEMPO DE EXECUCAO: cerca de 30 s no GNU Octave com os valores padrao.

rodarVarredura = true;      % false para pular esta secao
faixaFreq      = [55 65];   % [Hz] frequencias testadas
passoFreq      = 0.25;      % [Hz]
duracaoPonto   = 0.5;       % [s] registro em cada frequencia
limiteErro     = 2;         % [graus] pior erro absoluto aceitavel

if rodarVarredura

    freqs = faixaFreq(1):passoFreq:faixaFreq(2);
    nF = numel(freqs);
    z  = zeros(1, nF);
    V  = struct('freq', freqs, 'n', z, 'eMed', z, 'e05', z, 'e95', z, ...
                'eMin', z, 'eMax', z, 'eRms', z, 'fErr', z, 'fOsc', z, 'fRms', z);
    nP = round(duracaoPonto*Fs);
    tp = (0:nP-1)'/Fs;
    alpha = alphaDeg*pi/180;   mu = muDeg*pi/180;

    fprintf('\nVARREDURA DE FREQUENCIA: %g a %g Hz, passo de %g Hz, %g s por ponto\n', ...
            faixaFreq(1), faixaFreq(2), passoFreq, duracaoPonto);

    for q = 1:nF
        pq = p;  pq.fReal = freqs(q);
        wq = 2*pi*pq.fReal;

        xq = sinal_bloco(tp, pq);
        sg = sqrt(mean(xq.^2)/10^(snr/10));
        try, rng(2000 + q); catch, randn('seed', 2000 + q); end   %#ok<RAND>
        xq = xq + sg*randn(nP, 1);

        estq = struct('Nppc', N, 's1', 0, 's2', 1, 'Yc', 0, 'Ys', 0, ...
                      'buf', zeros(N, 1), 'n', 0);
        Phq = swrdft_bloco(xq, estq);

        % frequencia: diferenca de fase sobre exatamente uma janela
        fq = nan(nP, 1);
        dq = mod(Phq(N+1:end) - Phq(1:end-N) + pi, 2*pi) - pi;
        fq(N+1:end) = Fs/N + dq*Fs/(2*pi*N);
        fq(1:2*N)   = NaN;                         % so apos duas janelas

        % angulo de cada entalhe, no centro verdadeiro
        errq = zeros(1, 0);
        for cyc = 0:ceil(wq*tp(end)/(2*pi))
            for r = 0:5
                tcv = ((30 + 60*r)*pi/180 + alpha + mu/2 + 2*pi*cyc)/wq;
                j = round(tcv*Fs) + 1;
                if j < 1 || j > nP || isnan(fq(j)), continue; end
                th  = w0*j + Phq(j) + (2*pi*fq(j)/Fs - w0)*(N - 1)/2;
                thv = wq*((j - 1)/Fs) + pi/6;      % v_ab = sqrt(3)Vp sin(wt + 30)
                errq(end+1) = rad2deg(mod(th - thv + pi, 2*pi) - pi);   %#ok<AGROW>
            end
        end

        fv = fq(~isnan(fq));
        es = sort(errq);                       % percentis sem toolbox
        V.n(q)    = numel(errq);
        V.eMed(q) = mean(errq);
        V.e05(q)  = es(max(1, ceil(0.05*numel(es))));
        V.e95(q)  = es(max(1, ceil(0.95*numel(es))));
        V.eMin(q) = min(errq);
        V.eMax(q) = max(errq);
        V.eRms(q) = sqrt(mean(errq.^2));             % raiz do erro medio quadratico
        V.fErr(q) = mean(fv) - pq.fReal;
        V.fOsc(q) = std(fv);
        V.fRms(q) = sqrt(mean((fv - pq.fReal).^2));   % raiz do erro medio quadratico
    end

    % faixa em que funciona: trecho continuo em torno de 60 Hz em que o pior
    % caso fica dentro do limite
    pior   = max(abs(V.eMin), abs(V.eMax));
    dentro = pior <= limiteErro;
    [~, i60] = min(abs(freqs - f0));
    faixaOk = [];
    if dentro(i60)
        a = i60;  while a > 1  && dentro(a-1), a = a - 1; end
        b = i60;  while b < nF && dentro(b+1), b = b + 1; end
        faixaOk = [freqs(a) freqs(b)];
    end

    % ---------- tabela 5 ----------
    sep5 = repmat('-', 1, 83);
    fprintf('\nTABELA 5 - ERRO EM FUNCAO DA FREQUENCIA DA REDE (a cada 1 Hz)\n');
    fprintf('%s\n', sep5);
    fprintf('%7s | %5s | %9s | %17s | %7s | %11s | %10s\n', 'rede', 'ent.', ...
            'erro', '90 % dos entalhes', 'pior', 'erro medio', 'erro RMS');
    fprintf('%7s | %5s | %9s | %17s | %7s | %11s | %10s\n', '[Hz]', '', ...
            'medio [g]', 'entre [graus]', 'caso[g]', 'freq. [Hz]', 'freq. [Hz]');
    fprintf('%s\n', sep5);
    for q = 1:nF
        if abs(freqs(q) - round(freqs(q))) > 1e-9, continue; end
        if dentro(q), marca = ' '; else, marca = '*'; end
        fprintf('%7.2f | %5d | %+9.3f | %+7.2f e %+6.2f | %6.2f%s | %+11.5f | %10.4f\n', ...
                freqs(q), V.n(q), V.eMed(q), V.e05(q), V.e95(q), pior(q), marca, ...
                V.fErr(q), V.fRms(q));
    end
    fprintf('%s\n', sep5);
    fprintf('* pior caso fora do limite de %g graus\n', limiteErro);

    fprintf('\nRESUMO DA VARREDURA\n');
    if isempty(faixaOk)
        fprintf('  nenhuma frequencia com pior caso dentro de %g graus\n', limiteErro);
    else
        fprintf('  o metodo funciona (pior caso <= %g graus) de %.2f a %.2f Hz\n', ...
                limiteErro, faixaOk(1), faixaOk(2));
    end
    [rA, iA] = min(V.eRms);
    fprintf('  erro RMS do angulo: de %.2f graus (em %g Hz) a %.2f graus (pior caso)\n', ...
            rA, freqs(iA), max(V.eRms));
    fprintf('  erro medio da frequencia: no maximo %.5f Hz em toda a faixa\n', ...
            max(abs(V.fErr)));
    fprintf('  erro RMS da frequencia: de %.4f Hz (em %g Hz) a %.4f Hz (pior caso)\n', ...
            min(V.fRms), freqs(find(V.fRms == min(V.fRms), 1)), max(V.fRms));

    fprintf('\nCOMO LER\n');
    fprintf('  90 %% dos entalhes .. 90 %% dos entalhes tem erro nesse intervalo\n');
    fprintf('                        (entre os percentis de 5 %% e de 95 %%)\n');
    fprintf('  pior caso ........... maior erro absoluto entre todos os entalhes\n');
    fprintf('  erro RMS da freq. ... raiz do erro medio quadratico da frequencia\n');
    fprintf('                        estimada, amostra a amostra: junta o vies (erro\n');
    fprintf('                        medio) e a oscilacao numa so grandeza\n');
    fprintf('  A frequencia e medida bem em toda a faixa.  O que limita o metodo e\n');
    fprintf('  a dispersao do angulo, que cresce com o desvio porque a janela da\n');
    fprintf('  SWRDFT, do tamanho de um ciclo de 60 Hz, fecha cada vez menos um\n');
    fprintf('  ciclo real.  Uma janela que se ajustasse a frequencia estimada\n');
    fprintf('  ampliaria a faixa.\n');

    try
        plot_erro_frequencia(V);         % erro RMS da frequencia [%]
        plot_erro_fase(V);               % erro RMS do angulo dos entalhes
    catch err
        fprintf('\n(grafico nao exibido: %s)\n', err.message);
    end
else
    fprintf('\n(secao 5, varredura de frequencia, pulada: rodarVarredura = false)\n');
    V = [];  faixaOk = [];
end

pasta = fileparts(mfilename('fullpath'));
save(fullfile(pasta, 'resultado_teste_4.mat'), 'resultados', 'sinal', 'sementes', ...
     'desvios', 'tE', 'tipoE', 'verdE', 'erroE', 'V', 'faixaOk', 'limiteErro');
fprintf('\nResultado gravado em resultado_teste_4.mat\n');