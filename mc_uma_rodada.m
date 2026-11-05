function r = mc_uma_rodada(fReal, snr, semente, cfg)
% MC_UMA_RODADA
%
% Uma simulacao: gera um sinal, roda a cadeia completa (do jeito que esta
% na pasta) e compara tudo com a verdade de campo.  Devolve uma linha de
% resultados.
%
%   r = mc_uma_rodada(fReal, snr, semente, cfg)
%
%   fReal    frequencia real da rede [Hz]
%   snr      relacao sinal-ruido [dB]
%   semente  semente do ruido (o trio fReal, snr, semente define o sinal)
%   cfg      parametros fixos: Fs, f0, nCiclos, Vll, alphaDeg, muDeg,
%            Ls, Lt, e as harmonicas de fundo de UMA destas formas:
%              cfg.H    matriz [ordem amplitude(pu) fase(rad)], uma linha
%                       por harmonica (tem prioridade, se existir)
%              cfg.thd  THD total, distribuido por harmonicos_thd.m
%
% REFERENCIA DO ANGULO
%   O angulo verdadeiro e o da FUNDAMENTAL DO PROPRIO SINAL COM ENTALHES --
%   o que um instrumento real enxerga.  Os entalhes deslocam a fase da
%   fundamental (~-1,28 grau); com esta referencia, esse deslocamento nao
%   conta como erro do metodo.  Ele e medido na mesma onda SEM ruido, com e
%   sem entalhes, projetada na frequencia real sobre ciclos completos, e
%   somado ao angulo da onda ideal.
%
% INFLUENCIA DA FREQUENCIA ESTIMADA NA AREA (cfg.influenciaFreq = true)
%   Mede a area de cada entalhe uma segunda vez, com o detector sintonizado
%   na frequencia VERDADEIRA, e guarda a diferenca para a medida normal
%   (detector na frequencia estimada pela SWRDFT), em %.  Como o sinal e o
%   ruido sao os mesmos, a diferenca isola so o efeito da estimativa de
%   frequencia da SWRDFT sobre a area.  Custa uma segunda passada do
%   detector (sem a SWRDFT).
%
% PAREAMENTO
%   Os pares vem do proprio parear_eventos.m (saida parEvento): um evento
%   corresponde a um entalhe verdadeiro se os dois se sobrepoem no tempo,
%   ou se os centros estao a menos de 0,3 ms; um evento por entalhe.
%   Evento sem par e FALSO: entra na contagem de falsos e fica FORA das
%   estatisticas de angulo.  Assim, um erro de deteccao nao aparece
%   disfarcado de erro de angulo, e toda a avaliacao usa a mesma regra.

t0 = tic;

% ---------- sinal ----------
sinal = {'Modo', 'conversor', 'Fs', cfg.Fs, 'f0', cfg.f0, 'nCiclos', cfg.nCiclos, ...
         'Vll', cfg.Vll, 'Grandeza', 'fase-fase', 'alphaDeg', cfg.alphaDeg, ...
         'muDeg', cfg.muDeg, 'Ls', cfg.Ls, 'Lt', cfg.Lt, 'Bits', [], ...
         'SNRdb', snr, 'Harmonicos', harmonicas(cfg), ...
         'DesvioFreqHz', fReal - cfg.f0, 'Semente', semente};
[x, t, truth, meta] = gerar_sinal_teste(sinal{:});

% ---------- referencia do angulo verdadeiro ----------
refAng = 'fundamental';
xEnt = gerar_sinal_teste(sinal{:}, 'SNRdb', []);            % com entalhes, sem ruido
xIde = gerar_sinal_teste(sinal{:}, 'SNRdb', [], 'Ls', 0);   % onda ideal, sem entalhes
nPC  = cfg.Fs/meta.fReal;                                   % amostras por ciclo real
nCic = floor(numel(x)/nPC);
jj   = (round(nPC) + 1):round(nCic*nPC);                    % do 2o ao ultimo ciclo completo
z    = exp(-1j*2*pi*meta.fReal*t(jj));  z = z(:);
deslocRef = rad2deg(angle(sum(xEnt(jj(:)).*z)) - angle(sum(xIde(jj(:)).*z)));   % [graus]

% ---------- cadeia completa ----------
R = notch_analyze(x, cfg.Fs, cfg.f0, 'Vll', cfg.Vll);

% ---------- deteccao e medidas ----------
tC = (R.detector.iInicio + R.detector.Janela)/cfg.Fs;      % fim do aquecimento
tr = truth([truth.tInicio] > tC);
ev = R.eventos;
if ~isempty(ev), ev = ev([ev.tInicio] > tC); end
% eventos de MODELO REDUZIDO (semeadura sem o banco completo, logo apos o
% aquecimento) ficam de fora, junto com os entalhes verdadeiros que eles
% cobrem: a propria cadeia os marca como medidas nao confiaveis
nRed = 0;
if ~isempty(ev) && isfield(ev, 'modeloReduzido') && any([ev.modeloReduzido])
    red = ev([ev.modeloReduzido]);
    ev  = ev(~[ev.modeloReduzido]);
    nRed = numel(red);
    for kr = 1:nRed
        tr = tr(~([tr.tInicio] <= red(kr).tFim & [tr.tFim] >= red(kr).tInicio));
    end
end
P = parear_eventos(ev, tr);

% ---------- influencia da frequencia estimada (SWRDFT) na area ----------
eAreaFreq = [];
if isfield(cfg, 'influenciaFreq') && cfg.influenciaFreq && ~isempty(ev)
    Rv  = notch_analyze(x, cfg.Fs, fReal, 'Vll', cfg.Vll, 'EstimarFrequencia', false);
    ev2 = Rv.eventos;
    if ~isempty(ev2)
        ev2 = ev2([ev2.tInicio] > tC & ~[ev2.modeloReduzido]);
    end
    if ~isempty(ev2)
        c2 = 0.5*([ev2.tInicio] + [ev2.tFim]);
        for k = 1:numel(ev)
            [dmin, q] = min(abs(c2 - 0.5*(ev(k).tInicio + ev(k).tFim)));
            if dmin <= 2e-4                  % o mesmo entalhe nas duas medidas
                eAreaFreq(end+1) = 100*(ev(k).area - ev2(q).area)/ev2(q).area;  %#ok<AGROW>
            end
        end
    end
end

% ---------- pares (quem ficou com quem), da propria parear_eventos ----------
ent = P.entalhes;
tcv = 0.5*([ent.tInicio] + [ent.tFim]);    % centros verdadeiros
par = P.parEvento;                          % indice do entalhe de cada evento (0 = falso)

% detalhes de cada falso: instante, angulo na onda, largura e profundidade
falsos = zeros(0, 4);
for k = find(par == 0)
    tck = 0.5*(ev(k).tInicio + ev(k).tFim);
    falsos(end+1, :) = [tck, mod(360*meta.fReal*tck + 30, 360), ...
                        round((ev(k).tFim - ev(k).tInicio)*cfg.Fs) + 1, ev(k).maxDepth]; %#ok<AGROW>
end

% ---------- frequencia e angulo pela SWRDFT, so nos pares ----------
F  = fase_swrdft(x, cfg.Fs, cfg.f0);
fv = F.f(F.valido);
eLeit = [];  desl = [];  eTot = [];
for k = find(par > 0)
    tck = 0.5*(ev(k).tInicio + ev(k).tFim);
    ic  = round(tck*cfg.Fs) + 1;
    if ~F.valido(ic), continue; end
    angMed = mod(rad2deg(F.theta(ic)), 360);
    j = par(k);
    eLeit(end+1) = (mod((angMed) - (mod(360*meta.fReal*tck    + 30 + deslocRef, 360)) + 180, 360) - 180);  %#ok<AGROW>
    eTot(end+1)  = (mod((angMed) - (mod(360*meta.fReal*tcv(j) + 30 + deslocRef, 360)) + 180, 360) - 180);  %#ok<AGROW>
    desl(end+1)  = (tck - tcv(j))*cfg.Fs;                                 %#ok<AGROW>
end

% ---------- linha de resultados ----------
r.fReal    = fReal;
r.snr      = snr;
r.semente  = semente;
r.fEst     = R.frequencia.estimada;
r.erroF    = R.frequencia.estimada - fReal;
r.rmsF     = sqrt(mean((fv - fReal).^2));
r.nVerd    = P.nVerd;
r.nDet     = P.nDet;
r.falsos   = P.nFalsos;
r.perdidos = P.nPerdidos;
[r.profMed, r.profP90] = resumo(P.eProf);
[r.areaMed, r.areaP90] = resumo(P.eArea);
[r.largMed, r.largP90] = resumo(P.eLarg);
r.leitRms  = sqrt(mean(eLeit.^2));
r.locPior  = max(abs([desl 0]));
r.totRms   = sqrt(mean(eTot.^2));
r.totPior  = max(abs([eTot 0]));
r.refAngulo = refAng;      % referencia do angulo verdadeiro
r.deslocRef = deslocRef;   % deslocamento da fundamental pelos entalhes [graus]
r.reduzidos = nRed;        % eventos de modelo reduzido deixados de fora
r.detFalsos = falsos;       % [instante (s), angulo na onda (graus), amostras, profundidade (V)]
% erros individuais de cada entalhe pareado, para juntar varios sinais
r.eProf    = P.eProf;
r.eArea    = P.eArea;
r.eLarg    = P.eLarg;
r.eAng     = eTot;          % erro total do angulo [graus]
r.eAreaFreq = eAreaFreq;    % area (f estimada) - area (f verdadeira) [%], por entalhe
r.tempo    = toc(t0);
end

function H = harmonicas(cfg)
% matriz de harmonicas de fundo: cfg.H, se existir; senao, pelo THD total
if isfield(cfg, 'H')
    H = cfg.H;
else
    H = harmonicos_thd(cfg.thd);
end
end

function [med, p90] = resumo(v)
if isempty(v), med = NaN; p90 = NaN; return; end
a = sort(abs(v(:)));
med = median(v);
p90 = a(max(1, ceil(0.9*numel(a))));
end
