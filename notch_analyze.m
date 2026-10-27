function R = notch_analyze(x, Fs, f0, varargin)
% NOTCH_ANALYZE
%
% Analise completa de notching (entalhes de comutacao) num registro de
% tensao: adequacao da aquisicao, deteccao, medicao por entalhe,
% identificacao do conversor, indices agregados e conformidade.
%
% USO
%   R = notch_analyze(x, Fs, f0);
%   R = notch_analyze(x, Fs, f0, 'Vll', 480, 'Grandeza', 'fase-fase');
%   notch_report(R);
%   notch_plot(R);
%
% ENTRADAS
%   x   : sinal de TENSAO (vetor). Notching e um disturbio de tensao.
%   Fs  : taxa de amostragem [Hz]
%   f0  : frequencia fundamental NOMINAL [Hz].  A frequencia real e
%         estimada pela SWRDFT (ver EstimarFrequencia)
%
% PARES NOME/VALOR
%   'Vll'       : tensao fase-fase nominal eficaz [V]. Define a base da
%                 profundidade percentual e os limites da IEEE 519.
%                 Se vazio, usa a amplitude estimada do sinal.   (padrao [])
%   'Grandeza'  : 'fase-fase' (padrao) ou 'fase-neutro'.  Afeta a inferencia
%                 do numero de pulsos: fase-fase mostra Np entalhes por
%                 ciclo, fase-neutro mostra 2*Np/3.
%   'Arel'      : coeficiente de confiabilidade do detector      (padrao 3)
%   'Aplicacao' : 'especial' | 'geral' | 'dedicado' (IEEE 519)   (padrao 'geral')
%   'WmaxS'     : maior largura de entalhe admitida [s]          (padrao 1e-3)
%   'Ordens'    : ordens harmonicas do banco de ressonadores (padrao [1 5 7 11 13])
%   'JanelaAjuste': amostras da janela de semeadura; [] = N/2    (padrao [])
%   'AjusteRobusto': semeadura robusta contra o filtro anti-aliasing (padrao true)
%   'FecharLacunas': exclui da semeadura lacunas curtas [s]           (padrao 1e-3)
%   'EstimarFrequencia': estima a frequencia real pela SWRDFT e a usa em
%                    toda a analise; false = usa f0 nominal          (padrao true)
%   'FaixaFrequencia': maior desvio aceito para a estimativa [Hz]     (padrao 5)
%
% SAIDA  (struct R)
%   R.aquisicao  : amostras por entalhe e veredito de adequacao
%   R.eventos    : struct array, um por entalhe, com todos os parametros
%   R.conversor  : numero de pulsos inferido e qualidade da inferencia
%   R.indices    : estatisticas agregadas, NDR, NSI, cruzamentos extras
%   R.conformid  : comparacao com os limites informativos da IEEE 519
%   R.sinal      : x, t, xref, flag, epsilon (para os graficos)
%
% CONVENCOES DE MEDICAO
%   O desvio e medido contra xref, a forma de onda reconstruida sem os
%   entalhes.  Para cada entalhe sao reportados:
%     maxDepth  profundidade maxima        -- enviesada pelo ruido
%     avgDepth  profundidade media = A/w   -- e a definicao da IEEE 519 e
%                                             torna exata a identidade A=d*w
%     width     largura no contorno
%     width50   largura a 50% da profundidade -- mais reprodutivel
%     area      em V*us
%     kf        fator de forma A/(maxDepth*w):
%                 ~0,9  entalhe de comutacao retangular (alpha alto)
%                 ~0,5  entalhe triangular (alpha ~ 0)
%                 <0,4  transitorio impulsivo, NAO e entalhe
%     powDeg    angulo eletrico do centro do entalhe

% ---------------- opcoes ----------------
p = struct('Vll', [], 'Grandeza', 'fase-fase', 'Arel', 3, ...
           'Aplicacao', 'geral', 'WmaxS', 1e-3, ...
           'Ordens', [1 5 7 11 13], 'JanelaAjuste', [], ...
           'AjusteRobusto', true, 'FecharLacunas', 1e-3, ...
           'EstimarFrequencia', true, 'FaixaFrequencia', 5);
for a = 1:2:numel(varargin)
    if ~isfield(p, varargin{a})
        error('notch_analyze:badOption', 'Opcao desconhecida: %s', varargin{a});
    end
    p.(varargin{a}) = varargin{a+1};
end

x = x(:);
L = numel(x);
t = (0:L-1)'/Fs;

%% ---------- frequencia real da rede (SWRDFT) ----------
% Num sinal real a frequencia da rede nao e conhecida e varia em torno do
% nominal.  Supor o nominal fora dele degrada a reconstrucao (o banco de
% ressonadores fica dessintonizado) e o angulo de cada entalhe.  Aqui a
% frequencia e estimada pela SWRDFT, pela variacao da fase da fundamental,
% e o valor estimado substitui o nominal em TODA a analise a seguir:
% tamanho do ciclo, amplitude da fundamental, detector, angulo dos
% entalhes e identificacao do conversor.
%
% Salvaguardas: se o registro for curto demais para a SWRDFT (menos de um
% ciclo de estimativas validas, o que exige cerca de tres ciclos de
% registro) ou se a estimativa cair fora de +/- FaixaFrequencia em torno
% do nominal (faixa validada no teste 4), usa-se o nominal.
%
% Uma unica frequencia por registro: suficiente para frequencia constante.
% Registros longos com frequencia variando exigiriam uma frequencia por
% entalhe, passada ao detector -- ainda nao implementado.
f0Nominal = f0;
freq = struct('nominal', f0, 'estimada', NaN, 'oscilacao', NaN, ...
              'usada', f0, 'fonte', 'nominal (estimativa desligada)');
if p.EstimarFrequencia
    F  = fase_swrdft(x, Fs, f0);
    fv = F.f(F.valido);
    if numel(fv) >= Fs/f0
        freq.estimada  = mean(fv);
        freq.oscilacao = std(fv);
        if abs(freq.estimada - f0) <= p.FaixaFrequencia
            f0 = freq.estimada;
            freq.usada = f0;
            freq.fonte = 'SWRDFT';
        else
            freq.fonte = 'nominal (estimativa fora da faixa validada)';
            warning('notch_analyze:frequencia', ...
                    'Frequencia estimada (%.3f Hz) fora de +/- %g Hz do nominal; usando %g Hz.', ...
                    freq.estimada, p.FaixaFrequencia, f0Nominal);
        end
    else
        freq.fonte = 'nominal (registro curto demais para estimar)';
    end
end

N = Fs/f0;
T = 1/f0;

%% ---------- amplitude e base percentual ----------
% Amplitude da fundamental por projecao em quadratura (robusta a entalhes,
% que ocupam menos de 15% das amostras).
c = cos(2*pi*f0*t);
s = sin(2*pi*f0*t);
a1 = 2*mean(x.*s);
b1 = 2*mean(x.*c);
V1 = hypot(a1, b1);
phi1 = atan2(b1, a1);

if isempty(p.Vll)
    Vbase = V1;
    baseTxt = 'amplitude estimada da fundamental';
else
    Vbase = sqrt(2)*p.Vll;
    baseTxt = sprintf('pico fase-fase nominal (%g V eficazes)', p.Vll);
end

%% ---------- deteccao ----------
[ev, flag, xref, epsilon, infoDet] = ...
    notch_detector(x, Fs, f0, N, p.Arel, 'MaxWidth', 4e-3, ...
                   'Ordens', p.Ordens, 'JanelaAjuste', p.JanelaAjuste, ...
                   'AjusteRobusto', p.AjusteRobusto, ...
                   'FecharLacunas', p.FecharLacunas);

%% ---------- medicao por entalhe ----------
res = xref - x;
ne = numel(ev);

eventos = struct('indice',{},'tInicio',{},'tFim',{},'amostras',{}, ...
                 'width',{},'width50',{},'maxDepth',{},'avgDepth',{}, ...
                 'depthPct',{},'area',{},'kf',{},'powDeg',{}, ...
                 'polaridade',{},'ciclo',{},'snrLocal',{},'saturado',{}, ...
                 'modeloReduzido',{});

for k = 1:ne
    i1 = ev(k).startSample;
    i2 = ev(k).endSample;
    idx = i1:i2;
    r = res(idx);

    w  = ev(k).widthTime;
    A  = ev(k).area;                 % V*us
    dM = ev(k).maxDepth;
    dA = ev(k).avgDepth;

    % largura a 50% da profundidade, com interpolacao sub-amostra
    w50 = half_width(abs(r), Fs);

    kf = (A*1e-6)/max(dM*w, eps);

    tc = 0.5*(t(i1) + t(i2));
    powDeg = mod(180/pi*(2*pi*f0*tc + phi1), 360);

    eventos(k).indice     = k;
    eventos(k).tInicio    = t(i1);
    eventos(k).tFim       = t(i2);
    eventos(k).amostras   = numel(idx);
    eventos(k).width      = w;
    eventos(k).width50    = w50;
    eventos(k).maxDepth   = dM;
    eventos(k).avgDepth   = dA;
    eventos(k).depthPct   = 100*dM/Vbase;
    eventos(k).area       = A;
    eventos(k).kf         = min(kf, 1.5);
    eventos(k).powDeg     = powDeg;
    eventos(k).polaridade = sign(mean(r));
    eventos(k).ciclo      = floor(tc/T) + 1;
    eventos(k).snrLocal   = dM/max(infoDet.sigma, eps);

    % Marcacao SATURADA: o evento atingiu o limite MaxRun de reconstrucoes
    % seguidas, logo sua largura foi truncada pelo algoritmo e nao pelo fim
    % do entalhe.  Acontece tipicamente com entalhes de entrada GRADUAL
    % (alpha ~ 0, retificador a diodos): o detector nao dispara na subida
    % lenta, so na borda de recuperacao, e a reconstrucao acaba semeada por
    % uma amostra ja deprimida.  Largura e area desses eventos NAO sao
    % confiaveis.
    eventos(k).saturado   = ev(k).saturado;

    % Modelo REDUZIDO: o evento foi reconstruido sem todas as harmonicas,
    % porque ocorreu logo apos o aquecimento, antes de existirem amostras
    % processadas suficientes para o ajuste completo.  Com distorcao
    % harmonica de fundo, essa reconstrucao deriva e a medicao nao e
    % confiavel.  Esses eventos sao listados, mas ficam FORA das
    % estatisticas agregadas e da conformidade.
    eventos(k).modeloReduzido = (ev(k).semeadura < 3) && (numel(p.Ordens) > 1);
end

%% ---------- S0: adequacao da aquisicao ----------
if ne > 0
    wTip = median([eventos.width]);
else
    wTip = 3e-4;
end
spn = Fs*wTip;
if spn >= 10
    veredito = 'ADEQUADA';
elseif spn >= 5
    veredito = 'MARGINAL (erro de area entre 5 e 15%)';
else
    veredito = 'INADEQUADA (entalhe subamostrado)';
end

R.aquisicao = struct('Fs', Fs, 'larguraTipica', wTip, ...
    'amostrasPorEntalhe', spn, 'FsMinRecomendada', 10/max(wTip,eps), ...
    'veredito', veredito, 'sigmaRuido', infoDet.sigma, ...
    'regra', 'Fs >= 10/w garante erro de area abaixo de ~5%');

%% ---------- identificacao do conversor ----------
conv = infer_pulses(eventos, f0, p.Grandeza);

%% ---------- indices agregados ----------
% So entram eventos medidos com o modelo completo.
if ne > 0
    usar = true(1, ne);
    if isfield(eventos, 'modeloReduzido')
        usar = ~[eventos.modeloReduzido];
    end
    nRed = sum(~usar);
    if ~any(usar), usar = true(1, ne); nRed = 0; end
    ev2 = eventos(usar);

    d  = [ev2.depthPct];
    w  = [ev2.width];
    A  = [ev2.area];
    kf = [ev2.kf];
    cy = [ev2.ciclo];
    nCiclos = max(1, max(cy) - min(cy) + 1);

    % NDR: parcela de distorcao atribuivel ao notching, separada do
    % conteudo harmonico de fundo (que esta tanto em x quanto em xref).
    NDR = sqrt(mean(res.^2))/sqrt(mean(xref.^2));

    % NSI: fracao adimensional da area volt-segundo perdida por ciclo.
    areaPorCiclo = sum(A)/nCiclos;                 % V*us
    NSI = (areaPorCiclo*1e-6)/(Vbase*T);

    R.indices = struct( ...
        'nEntalhes', ne, 'nCiclos', nCiclos, ...
        'nModeloReduzido', nRed, 'nNasEstatisticas', numel(ev2), ...
        'entalhesPorCiclo', numel(ev2)/nCiclos, ...
        'depthPctMedia', mean(d), 'depthPctCP95', pct95(d), 'depthPctMax', max(d), ...
        'widthUsMedia', 1e6*mean(w), 'widthUsCP95', 1e6*pct95(w), ...
        'areaMedia', mean(A), 'areaCP95', pct95(A), 'areaMax', max(A), ...
        'areaPorCiclo', areaPorCiclo, ...
        'kfMediano', median(kf), 'NDR', NDR, 'NSI', NSI, ...
        'nSaturados', sum([ev2.saturado]), ...
        'cruzamentosZeroExtras', extra_zc(x, xref));
else
    R.indices = struct('nEntalhes', 0);
end

%% ---------- conformidade IEEE 519 ----------
R.conformid = ieee519(R.indices, p.Vll, p.Aplicacao, Vbase);

%% ---------- empacota ----------
R.eventos   = eventos;
R.conversor = conv;
R.sinal     = struct('x', x, 't', t, 'xref', xref, 'flag', flag, ...
                     'epsilon', epsilon, 'res', res);
R.detector  = infoDet;
R.frequencia = freq;
R.config    = struct('Fs', Fs, 'f0', f0, 'f0Nominal', f0Nominal, 'V1', V1, 'Vbase', Vbase, ...
                     'baseTxt', baseTxt, 'Grandeza', p.Grandeza, ...
                     'Aplicacao', p.Aplicacao, 'Arel', p.Arel);
end


% =====================================================================
function w50 = half_width(ar, Fs)
% Largura a meia altura, com interpolacao linear nos cruzamentos.
    if numel(ar) < 3
        w50 = numel(ar)/Fs; return
    end
    pk = max(ar);
    if pk <= 0, w50 = 0; return; end
    idx = find(ar >= 0.5*pk);
    i0 = idx(1); i1 = idx(end);
    if i0 > 1
        den = max(ar(i0) - ar(i0-1), eps);
        left = i0 - (ar(i0) - 0.5*pk)/den;
    else
        left = i0;
    end
    if i1 < numel(ar)
        den = max(ar(i1) - ar(i1+1), eps);
        right = i1 + (ar(i1) - 0.5*pk)/den;
    else
        right = i1;
    end
    w50 = (right - left)/Fs;
end


function conv = infer_pulses(eventos, f0, grandeza)
% Infere o numero de pulsos do conversor a partir da periodicidade dos
% entalhes.
%
% Cada comutacao envolve 2 das 3 fases, logo:
%   fase-fase   -> Np entalhes por ciclo, equiespacados de T/Np
%   fase-neutro -> 2*Np/3 entalhes por ciclo, com intervalos ALTERNADOS
%                  (60 e 120 graus), nao equiespacados
%
% Por isso a inferencia so e confiavel em fase-fase; em fase-neutro o
% teste de equiespacamento falha por construcao.
    conv = struct('pulsos', 0, 'periodico', false, 'escore', 0, ...
                  'entalhesPorCiclo', 0, 'observacao', '');
    n = numel(eventos);
    if n < 4
        conv.observacao = 'poucos eventos para inferir';
        return
    end
    tc = sort(0.5*([eventos.tInicio] + [eventos.tFim]));
    dt = diff(tc);
    T = 1/f0;

    melhor = 0; escore = 0;
    for Np = [6 12 18 3 2]
        alvo = T/Np;
        prox = abs(dt - alvo) <= 0.20*alvo;
        if mean(prox) > escore
            escore = mean(prox); melhor = Np;
        end
    end

    conv.escore = escore;
    conv.periodico = escore >= 0.6;
    conv.entalhesPorCiclo = n/max(1, (tc(end)-tc(1))/T + 1);

    if strcmpi(grandeza, 'fase-neutro')
        if conv.periodico
            conv.pulsos = round(1.5*melhor);
            conv.observacao = ['medida fase-neutro: Np = 1,5 x entalhes/ciclo. ' ...
                               'A inferencia e mais fragil aqui porque os ' ...
                               'intervalos alternam 60 e 120 graus.'];
        else
            conv.observacao = ['medida fase-neutro: intervalos nao equiespacados ' ...
                               'por construcao. Prefira medir fase-fase.'];
        end
    else
        if conv.periodico
            conv.pulsos = melhor;
            conv.observacao = 'medida fase-fase: Np = entalhes por ciclo.';
        else
            conv.observacao = ['sem periodicidade clara: possivel superposicao ' ...
                               'de varios conversores, ou eventos que nao sao ' ...
                               'entalhes de comutacao.'];
        end
    end
end


function v = pct95(y)
    y = sort(y(:));
    if isempty(y), v = NaN; return; end
    k = max(1, min(numel(y), ceil(0.95*numel(y))));
    v = y(k);
end


function n = extra_zc(x, xref)
% Cruzamentos por zero EXCEDENTES introduzidos pelo notching.
% A IEEE 1159 (4.4.5.4) alerta que eles causam erro de frequencia em
% circuitos que contam passagens por zero e erro de disparo em conversores
% com sincronismo lento.
    z1 = sum(diff(x > 0) ~= 0);
    z2 = sum(diff(xref > 0) ~= 0);
    n = max(0, z1 - z2);
end


function C = ieee519(ind, Vll, aplic, Vbase)
% Limites INFORMATIVOS da IEEE Std 519-1992 para notching em baixa tensao
% (tabela de 480 V).  A area escala com a tensao: A_lim = A_480 * V/480.
%
% ATENCAO: estes valores sao da edicao de 1992.  A edicao 2014 reorganizou
% o material.  Verifique contra a sua copia da norma antes de usar em laudo.
    switch lower(aplic)
        case 'especial', lim = struct('depthPct',10,'area480',16400,'thd',3);
        case 'dedicado', lim = struct('depthPct',50,'area480',36500,'thd',10);
        otherwise,       lim = struct('depthPct',20,'area480',22800,'thd',5);
    end
    if isempty(Vll), Vll = Vbase/sqrt(2); end
    areaLim = lim.area480*(Vll/480);

    C = struct('aplicacao', aplic, 'limDepthPct', lim.depthPct, ...
               'limArea', areaLim, 'edicao', '1992 (informativo)');
    if isfield(ind, 'depthPctCP95')
        C.depthPct = ind.depthPctCP95;
        C.area     = ind.areaCP95;
        C.depthOK  = ind.depthPctCP95 <= lim.depthPct;
        C.areaOK   = ind.areaCP95     <= areaLim;
    else
        C.depthPct = NaN; C.area = NaN; C.depthOK = true; C.areaOK = true;
    end
end
