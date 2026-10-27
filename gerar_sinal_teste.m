function [x, t, truth, meta] = gerar_sinal_teste(varargin)
% GERAR_SINAL_TESTE
%
% Gera sinais de tensao com entalhes de comutacao e VERDADE DE CAMPO, para
% testar e calibrar a cadeia de analise de notching.
%
% USO
%   [x,t,truth,meta] = gerar_sinal_teste();                    % padroes
%   [x,t,truth,meta] = gerar_sinal_teste('alphaDeg',60,'SNRdb',45);
%   gerar_sinal_teste('Arquivo','caso1.mat');                  % grava .mat
%
% DOIS MODOS
% ----------
% 'conversor' (padrao) -- modelo FISICO de uma ponte de 6 pulsos.
%     Durante a comutacao entre as fases X (saindo) e Y (entrando), o
%     conversor curto-circuita as duas.  No ponto de medicao:
%         dv_X = +rho*(e_Y-e_X)/2,  dv_Y = -rho*(e_Y-e_X)/2,  dv_Z = 0
%     com rho = Ls/(Ls+Lt).  Como e_XY = -sqrt(3)*Vp*sin(delta), sendo
%     delta contado do cruzamento natural, a profundidade cresce com
%     sin(delta): entalhes TRIANGULARES e rasos para alpha ~ 0,
%     RETANGULARES e profundos para alpha grande.
%     A tensao fase-fase mostra 6 entalhes/ciclo (2 profundos + 4 com
%     metade); a fase-neutro mostra 4.
%
% 'parametrico' -- entalhes trapezoidais com profundidade, largura e
%     posicao impostas diretamente.  Nao e fisicamente fiel, mas permite
%     varrer um parametro de cada vez.
%
% PARES NOME/VALOR
%   --- gerais ---
%   'Modo'          'conversor' | 'parametrico'          (padrao conversor)
%   'Fs'            taxa de amostragem [Hz]              (padrao 100e3)
%   'f0'            frequencia [Hz]                      (padrao 60)
%   'nCiclos'       numero de ciclos                     (padrao 10)
%   'Vll'           tensao fase-fase eficaz [V]          (padrao 480)
%   'Grandeza'      'fase-fase' | 'fase-neutro'          (padrao fase-fase)
%   'Semente'       semente do gerador aleatorio         (padrao 1)
%
%   --- modo conversor ---
%   'alphaDeg'      angulo de disparo [graus]            (padrao 35)
%   'muDeg'         angulo de sobreposicao [graus]       (padrao 9)
%                   use [] para calcular a partir de Id
%   'Id'            corrente CC [A], se muDeg for []     (padrao [])
%   'Ls'            indutancia da fonte [H]              (padrao 30e-6)
%   'Lt'            indutancia de isolamento [H]         (padrao 70e-6)
%
%   --- modo parametrico ---
%   'ProfundidadePu' profundidade em pu do pico          (padrao 0.25)
%   'LarguraS'       largura [s]                         (padrao 4e-4)
%   'EntalhesPorCiclo'                                   (padrao 6)
%   'PowOffsetDeg'   deslocamento do primeiro entalhe    (padrao 15)
%   'JitterProf'     dispersao relativa da profundidade  (padrao 0.08)
%   'JitterLarg'     dispersao relativa da largura       (padrao 0.08)
%
%   --- perturbacoes comuns ---
%   'Harmonicos'    matriz [ordem amplitude_pu fase_rad; ...]   (padrao [])
%   'SNRdb'         relacao sinal-ruido [dB]; [] = limpo (padrao [])
%   'RingAmpl'      amplitude do ringing, fracao da profundidade (padrao 0)
%   'RingFreq'      frequencia do ringing [Hz]           (padrao 5000)
%   'RingTau'       constante de tempo do ringing [s]    (padrao 1.5e-4)
%   'Confundidores' numero de transitorios impulsivos    (padrao 0)
%                   servem para testar SELETIVIDADE: nao sao entalhes
%
%   --- emulacao do instrumento ---
%   'FsAquisicao'   reamostra com anti-aliasing [Hz]; [] = nao (padrao [])
%                   A taxa de geracao 'Fs' e ajustada automaticamente para
%                   o menor multiplo inteiro de FsAquisicao >= Fs, para que
%                   a decimacao seja exata.  Ex.: 15,36 kS/s -> gera a
%                   107,52 kS/s e decima por 7.
%   'Bits'          quantizacao do ADC; [] = nao quantiza (padrao 16)
%
%   --- rede ---
%   'DesvioFreqHz'  desvio da frequencia real em relacao a nominal [Hz].
%                   O sinal e gerado em f0+desvio; meta.f0 continua
%                   nominal, como o analisador conheceria.  (padrao 0)
%                   Para INTER-HARMONICOS use ordens nao inteiras em
%                   'Harmonicos', p. ex. [3.5 0.01 0].
%
%   --- saida ---
%   'Arquivo'       grava x, t, truth, meta num .mat     (padrao '')
%
% SAIDAS
%   x     : sinal de tensao
%   t     : tempo [s]
%   truth : struct array com tInicio, tFim, profundidade, area, tipo
%   meta  : rho, Vpico, parametros usados
%
% EXEMPLOS
%   % retificador a diodos: entalhe triangular e raso
%   [x,t] = gerar_sinal_teste('alphaDeg',0,'muDeg',14);
%
%   % ponte muito carregada, medida junto ao conversor
%   [x,t] = gerar_sinal_teste('alphaDeg',60,'Ls',80e-6,'Lt',20e-6);
%
%   % o que um medidor de 256 pontos/ciclo enxergaria
%   [x,t] = gerar_sinal_teste('FsAquisicao',15.36e3,'Bits',16);
%
%   % teste de seletividade
%   [x,t] = gerar_sinal_teste('SNRdb',45,'Confundidores',3);

%% ---------------- opcoes ----------------
p = struct( ...
    'Modo','conversor', 'Fs',100e3, 'f0',60, 'nCiclos',10, 'Vll',480, ...
    'Grandeza','fase-fase', 'Semente',1, ...
    'alphaDeg',35, 'muDeg',9, 'Id',[], 'Ls',30e-6, 'Lt',70e-6, ...
    'ProfundidadePu',0.25, 'LarguraS',4e-4, 'EntalhesPorCiclo',6, ...
    'PowOffsetDeg',15, 'JitterProf',0.08, 'JitterLarg',0.08, ...
    'Harmonicos',[], 'SNRdb',[], ...
    'RingAmpl',0, 'RingFreq',5000, 'RingTau',1.5e-4, 'Confundidores',0, ...
    'FsAquisicao',[], 'Bits',16, 'Arquivo','', 'DesvioFreqHz',0);

for a = 1:2:numel(varargin)
    if ~isfield(p, varargin{a})
        error('gerar_sinal_teste:badOption','Opcao desconhecida: %s', varargin{a});
    end
    p.(varargin{a}) = varargin{a+1};
end

semear(p.Semente);

% ---- taxa de geracao compativel com a taxa de aquisicao ----
% A decimacao so e exata se a taxa de geracao for MULTIPLO INTEIRO da taxa
% de aquisicao.  Uma versao anterior decimava por round(Fs/FsAquisicao):
% para 100 kS/s -> 15,36 kS/s isso da 7, e a taxa real virava 14,29 kS/s
% enquanto o analisador era informado de 15,36 kS/s -- um erro de 7,5 %
% na base de tempo, equivalente a enxergar a rede em 64,5 Hz.
% Aqui a taxa de geracao e ajustada para o menor multiplo inteiro da taxa
% de aquisicao que seja pelo menos a taxa pedida.
if ~isempty(p.FsAquisicao) && p.FsAquisicao < p.Fs
    fatorDec = ceil(p.Fs/p.FsAquisicao - 1e-9);
    p.Fs = fatorDec*p.FsAquisicao;
end

Fs = p.Fs;  f0 = p.f0;
% O sinal e gerado na frequencia REAL; meta.f0 continua sendo a NOMINAL,
% que e o que o analisador conhece -- exatamente como num medidor real.
fReal = f0 + p.DesvioFreqHz;
w  = 2*pi*fReal;
T  = 1/fReal;
n  = round(p.nCiclos*T*Fs);
t  = (0:n-1)'/Fs;

Vp    = sqrt(2)*p.Vll/sqrt(3);     % pico fase-neutro
Vllpk = sqrt(2)*p.Vll;             % pico fase-fase

truth = struct('tInicio',{},'tFim',{},'profundidade',{},'area',{},'tipo',{});

%% ================= geracao =================
switch lower(p.Modo)

    case 'conversor'
        [x, truth, rho, muUsado] = modo_conversor(p, t, n, w, Vp, Fs, T);
        meta = struct('modo','conversor','rho',rho,'muDeg',muUsado, ...
                      'alphaDeg',p.alphaDeg,'Vpico',Vllpk, ...
                      'entalhesPorCicloEsperado', 6);
        if strcmpi(p.Grandeza,'fase-neutro')
            meta.Vpico = Vp;
            meta.entalhesPorCicloEsperado = 4;
        end

    case 'parametrico'
        [x, truth] = modo_parametrico(p, t, n, w, Vllpk, Fs, T);
        meta = struct('modo','parametrico','rho',NaN,'muDeg',NaN, ...
                      'alphaDeg',NaN,'Vpico',Vllpk, ...
                      'entalhesPorCicloEsperado', p.EntalhesPorCiclo);

    otherwise
        error('gerar_sinal_teste:badMode','Modo invalido: %s', p.Modo);
end

%% ================= harmonicos de fundo =================
if ~isempty(p.Harmonicos)
    for r = 1:size(p.Harmonicos,1)
        h  = p.Harmonicos(r,1);
        am = p.Harmonicos(r,2);
        ph = p.Harmonicos(r,3);
        x = x + meta.Vpico*am*sin(h*w*t + ph);
    end
end

%% ================= confundidores =================
% Transitorios impulsivos: NAO sao entalhes.  Um bom analisador deve
% rejeita-los pelo fator de forma (k_f < 0,4) e pela falta de periodicidade.
for c = 1:p.Confundidores
    i0 = round((0.1 + 0.8*rand)*n);
    dur = 2e-5 + 8e-5*rand;
    ns  = max(3, round(dur*Fs));
    amp = (0.3 + 0.5*rand)*meta.Vpico*sign(randn);
    tt  = (0:ns-1)'/Fs;
    pulso = amp*exp(-tt/(dur/3)).*sin(2*pi*(1/(2*dur))*tt);
    j1 = min(n, i0+ns-1);
    x(i0:j1) = x(i0:j1) + pulso(1:(j1-i0+1));

    k = numel(truth) + 1;
    truth(k).tInicio      = (i0-1)/Fs;
    truth(k).tFim         = (j1-1)/Fs;
    truth(k).profundidade = abs(amp);
    truth(k).area         = NaN;
    truth(k).tipo         = 'transitorio';
end

%% ================= ruido =================
if ~isempty(p.SNRdb) && isfinite(p.SNRdb)
    pSig = mean(x.^2);
    x = x + sqrt(pSig/10^(p.SNRdb/10))*randn(n,1);
end

%% ================= cadeia de aquisicao =================
% Emula o instrumento: filtro anti-aliasing analogico, decimacao e
% quantizacao.  E assim que se descobre que a profundidade medida e tanto
% propriedade do medidor quanto do fenomeno.
if ~isempty(p.FsAquisicao) && p.FsAquisicao < Fs
    [x, t] = cadeia_aquisicao(x, t, Fs, p.FsAquisicao);
    meta.FsGeracao    = Fs;
    meta.fatorDecimacao = round(Fs/p.FsAquisicao);
    Fs = p.FsAquisicao;
end
meta.Fs = Fs;
meta.f0 = f0;
meta.fReal = fReal;
meta.Vll = p.Vll;
meta.Grandeza = p.Grandeza;

if ~isempty(p.Bits)
    vr = 1.5*max(abs(x));
    q  = 2*vr/(2^p.Bits);
    x  = round(x/q)*q;
    meta.Bits = p.Bits;
end

%% ================= informacao util =================
nEnt = sum(strcmp({truth.tipo},'entalhe'));
if nEnt > 0
    larg = median([truth(strcmp({truth.tipo},'entalhe')).tFim] - ...
                  [truth(strcmp({truth.tipo},'entalhe')).tInicio]);
    meta.amostrasPorEntalhe = Fs*larg;
    meta.larguraTipica = larg;
else
    meta.amostrasPorEntalhe = NaN;
    meta.larguraTipica = NaN;
end
meta.nEntalhes = nEnt;

%% ================= gravacao =================
if ~isempty(p.Arquivo)
    save(p.Arquivo, 'x', 't', 'truth', 'meta');
    fprintf('Sinal gravado em %s  (%d amostras, %d entalhes)\n', ...
            p.Arquivo, numel(x), nEnt);
end
end


% =====================================================================
function [x, truth, rho, muDeg] = modo_conversor(p, t, n, w, Vp, Fs, T)
% Modelo fisico da ponte de 6 pulsos.

rho = p.Ls/(p.Ls + p.Lt);

muDeg = p.muDeg;
if isempty(muDeg)
    if isempty(p.Id)
        error('gerar_sinal_teste:semMu','Informe muDeg ou Id.');
    end
    % cos(alpha) - cos(alpha+mu) = 2*w*Lc*Id/(sqrt(2)*Vll)
    Lc = p.Ls + p.Lt;
    kk = 2*w*Lc*p.Id/(sqrt(2)*p.Vll);
    aa = p.alphaDeg*pi/180;
    arg = max(-1, min(1, cos(aa) - kk));
    muDeg = max(0, (acos(arg) - aa)*180/pi);
end

e = [ Vp*sin(w*t), Vp*sin(w*t - 2*pi/3), Vp*sin(w*t + 2*pi/3) ];
dv = zeros(n,3);

% angulo natural, fase que sai, fase que entra   (1=a, 2=b, 3=c)
comm = [  30 3 1;   90 2 3;  150 1 2;  210 3 1;  270 2 3;  330 1 2 ];

alpha = p.alphaDeg*pi/180;
mu    = muDeg*pi/180;

faseFase = strcmpi(p.Grandeza,'fase-fase');
truth = struct('tInicio',{},'tFim',{},'profundidade',{},'area',{},'tipo',{});
kk = 0;

for cyc = 0:p.nCiclos
    for r = 1:size(comm,1)

        th0 = comm(r,1)*pi/180 + 2*pi*cyc;
        io  = comm(r,2);
        ii  = comm(r,3);

        tStart = (th0 + alpha)/w;
        tEnd   = (th0 + alpha + mu)/w;
        if tStart >= t(end), continue; end

        i0 = ceil(tStart*Fs) + 1;
        i1 = min(floor(tEnd*Fs) + 1, n);
        if i1 <= i0, continue; end
        idx = i0:i1;

        dHalf = rho*(e(idx,ii) - e(idx,io))/2;

        dv(idx,io) = dv(idx,io) + dHalf;
        dv(idx,ii) = dv(idx,ii) - dHalf;

        % ---- verdade de campo para a grandeza escolhida ----
        if faseFase
            % v_ab: profundo quando o par que comuta e {a,b}
            if (io <= 2) && (ii <= 2), fac = 1.0; else, fac = 0.5; end
            seg = fac*2*dHalf;
        else
            % v_a: so registra se a fase a participou da comutacao
            if io == 1
                seg = dHalf;
            elseif ii == 1
                seg = -dHalf;
            else
                continue
            end
        end

        kk = kk + 1;
        truth(kk).tInicio      = tStart;
        truth(kk).tFim         = tEnd;
        truth(kk).profundidade = max(abs(seg));
        truth(kk).area         = trapz(abs(seg))/Fs*1e6;
        truth(kk).tipo         = 'entalhe';

        % ---- ringing ----
        if p.RingAmpl > 0 && i1 < n
            j1 = i1 + 1;
            j2 = min(n, j1 + round(6*p.RingTau*Fs));
            if j2 > j1
                tt = (0:(j2-j1))'/Fs;
                env = p.RingAmpl*abs(dHalf(end));
                osc = env*exp(-tt/p.RingTau).*sin(2*pi*p.RingFreq*tt);
                dv(j1:j2,io) = dv(j1:j2,io) + osc;
                dv(j1:j2,ii) = dv(j1:j2,ii) - osc;
            end
        end
    end
end

v = e + dv;
if faseFase
    x = v(:,1) - v(:,2);
else
    x = v(:,1);
end
end


% =====================================================================
function [x, truth] = modo_parametrico(p, t, n, w, Vpk, Fs, T)
% Entalhes trapezoidais com parametros impostos.

x = Vpk*sin(w*t);
truth = struct('tInicio',{},'tFim',{},'profundidade',{},'area',{},'tipo',{});

passo = T/p.EntalhesPorCiclo;
kk = 0;

for cyc = 0:(p.nCiclos-1)
    for m = 0:(p.EntalhesPorCiclo-1)

        tc = cyc*T + (p.PowOffsetDeg*pi/180)/w + m*passo;
        wd = p.LarguraS*(1 + p.JitterLarg*randn);
        dp = p.ProfundidadePu*Vpk*(1 + p.JitterProf*randn);
        wd = max(wd, 3/Fs);

        i0 = max(1, round((tc - wd/2)*Fs) + 1);
        i1 = min(n, round((tc + wd/2)*Fs) + 1);
        if i1 - i0 < 2, continue; end

        ns = i1 - i0 + 1;
        nr = max(1, round(0.15*ns));
        perfil = ones(ns,1);
        perfil(1:nr)       = linspace(0,1,nr)';
        perfil(end-nr+1:end) = linspace(1,0,nr)';

        % o entalhe empurra a tensao em direcao ao zero
        sgn = -sign(x(round((i0+i1)/2)));
        if sgn == 0, sgn = -1; end
        seg = sgn*dp*perfil;

        x(i0:i1) = x(i0:i1) + seg;

        if p.RingAmpl > 0 && i1 < n
            j1 = i1 + 1;
            j2 = min(n, j1 + round(6*p.RingTau*Fs));
            if j2 > j1
                tt = (0:(j2-j1))'/Fs;
                x(j1:j2) = x(j1:j2) - sgn*p.RingAmpl*dp* ...
                           exp(-tt/p.RingTau).*sin(2*pi*p.RingFreq*tt);
            end
        end

        kk = kk + 1;
        truth(kk).tInicio      = (i0-1)/Fs;
        truth(kk).tFim         = (i1-1)/Fs;
        truth(kk).profundidade = dp;
        truth(kk).area         = trapz(abs(seg))/Fs*1e6;
        truth(kk).tipo         = 'entalhe';
    end
end
end


% =====================================================================
function [y, ty] = cadeia_aquisicao(x, t, Fs, FsNovo)
% Filtro anti-aliasing (FIR janelado, sem dependencia de toolbox) seguido
% de decimacao.  O filtro e simetrico, logo nao introduz atraso de fase.
fc = 0.4*FsNovo;
M  = 2*round(4*Fs/fc) + 1;              % comprimento impar
k  = (-(M-1)/2:(M-1)/2)';
h  = 2*(fc/Fs)*sinc_local(2*(fc/Fs)*k);
h  = h.*(0.54 - 0.46*cos(2*pi*(0:M-1)'/(M-1)));   % Hamming
h  = h/sum(h);

xf = conv(x, h, 'same');

razao = Fs/FsNovo;
passo = round(razao);
if abs(razao - passo) > 1e-9 || passo < 1
    error('gerar_sinal_teste:decimacao', ...
          ['Taxa de geracao (%g) nao e multiplo inteiro da taxa de ' ...
           'aquisicao (%g): a decimacao alteraria a base de tempo.'], Fs, FsNovo);
end
y  = xf(1:passo:end);
ty = t(1:passo:end);
end

function y = sinc_local(z)
y = ones(size(z));
j = z ~= 0;
y(j) = sin(pi*z(j))./(pi*z(j));
end

function semear(s)
% Semeia o gerador aleatorio de forma compativel com MATLAB e Octave.
try
    rng(s);
catch
    randn('seed', s);   %#ok<RAND>
    rand('seed',  s);   %#ok<RAND>
end
end
