# Histórico do projeto — resultados, decisões e protótipos

Complemento do `CLAUDE.md`. Aqui estão os números, o raciocínio por trás de cada decisão,
e o código de protótipos testados que **não estão** na pasta `notching_escalabilidade`.
Todos os números foram obtidos no GNU Octave 8.4 (no MATLAB, os casos com ruído podem
diferir levemente, porque o gerador aleatório é outro).

---

## 1. Linha do tempo

1. **Toolkit em Python** (`notchlab`, pasta antiga `notchlab_toolkit`): primeira versão
   do método e um guia em PDF. Hoje é legado.
2. **Cadeia em MATLAB** (pasta antiga `notching_final`): reconstrução do `notch_detector.m`
   original do usuário, com correções — semeadura em quadratura, piso de ruído,
   reancoragem, σ pela segunda diferença, área em V·µs — e o banco de ressonadores.
3. **Investigação do filtro anti-aliasing** (T0 a T8, pasta antiga `investigacao_filtro`):
   - o gerador tinha um erro de base de tempo na decimação (corrigido);
   - um filtro FIR de fase linear tem 8,4% de sobressinal e pré-oscilação; as oscilações
     disparavam eventos e contaminavam a janela de semeadura do banco;
   - correções adotadas: **ajuste robusto** (Tukey) e **fechamento de lacunas** na
     semeadura — a 25 kS/s com filtro, P90 de profundidade de 82% para 22%;
   - rejeitado: filtro de largura mínima (viés de sobrevivência — descartava entalhes reais);
   - limitações identificadas: a regra de decisão testa a variação bruta, não o desvio em
     relação a uma previsão → cega para degraus contra a inclinação da onda e para entalhes
     de entrada gradual (α ≈ 0).
   O instrumento (filtro, quantização) ficou **em espera** por decisão do usuário.
4. **Escada de escalabilidade** (pasta atual): testes 1 a 3, depois a taxa passou de
   100 kS/s para **62,5 kS/s** (a taxa do usuário).
5. **SWRDFT** (arquivo do usuário): primeiro como estimador de frequência e ângulo (teste 4),
   depois **integrada ao `notch_analyze`** para estimar a frequência real e sintonizar o
   detector.
6. Teste 4 ganhou: registro longo em blocos (seção 4), varredura de 55 a 65 Hz (seção 5),
   Tabela 2B (localização e erro total), gráficos em RMS.
7. **Monte Carlo**: plano de 60 600 casos e piloto de 10 casos → revelou falsos positivos
   com ruído baixo → investigação de regras de decisão → regra "secante" validada numa cópia.
8. Avaliação de um detector alternativo do usuário (`notch_swrdbscan`) — não adotado.

---

## 2. Integração da SWRDFT na cadeia (antes × depois)

Medição com a rede fora de 60 Hz (ruído 55 dB, THD 4%, 3 sementes, 62,5 kS/s):

| Desvio | Antes (60 Hz fixo): falsos / P90 prof. / P90 área / veredito | Depois (SWRDFT) |
|---|---|---|
| −2 Hz | 7 / 53,6% / 153% / QUEBROU | 0 / 1,5% / 2,3% / OK |
| −1 Hz | 0 / 36,7% / 102% / QUEBROU | 0 / 1,8% / 2,3% / OK |
| −0,5 Hz | 1 / 15,1% / 13,1% / ATENÇÃO | 0 / 1,7% / 2,2% / OK |
| 0 Hz | 0 / 1,7% / 2,2% / OK | idêntico |
| +0,5 Hz | 0 / 12,9% / 10,5% / ATENÇÃO | 0 / 1,6% / 2,3% / OK |
| +1 Hz | 0 / 43,3% / 40,9% / QUEBROU | 0 / 1,6% / 2,3% / OK |
| +2 Hz | 3 / 68,3% / 230% / QUEBROU | 0 / 1,4% / 2,3% / OK |

Localização dos entalhes a ±2 Hz: antes, centro detectado 15 a 26 amostras fora (até 44);
depois, menos de 1 amostra. Testes 1 a 3 praticamente idênticos (diferenças ≤ 0,1 ponto).

---

## 3. SWRDFT — o que foi aprendido

- **Frequência**: erro médio ≤ 0,002 Hz de 55 a 65 Hz; a estimativa amostra a amostra
  oscila (vazamento quando a janela de 1042 amostras não fecha um ciclo real), mas a
  oscilação se cancela na média. Erro RMS de 0,003 Hz (0,005%) perto de 60 Hz a 0,29 Hz
  (0,53%) em 55 Hz.
- **Fase instantânea**: θ(i) = ω0·i + φ(i) + (ω̂ − ω0)(N−1)/2 — a correção de meio ciclo é
  obrigatória fora de 60 Hz (sem ela, ~3°/Hz de erro). A SWRDFT **mede** a fase a cada
  instante, por isso o erro **não acumula**: 10 min a 60,5 Hz, 217 759 entalhes, −0,994°
  em todos os minutos, tendência compatível com zero.
- **Erro fixo por tipo de entalhe**: fora de 60 Hz, o vazamento faz a fase oscilar 2× por
  ciclo; cada um dos 6 entalhes lê essa oscilação sempre no mesmo ponto → erro constante
  por tipo, com padrão que se repete a cada 180°.
- **Faixa de funcionamento do ângulo** (pior caso ≤ 2°): 57,75 a 62,75 Hz. Ângulo RMS de
  0,85° a 2,52° de 55 a 65 Hz.
- **Harmônicas pela SWRDFT**: corretas em 60 Hz (erro ≤ 0,7%), mas oscilam 5% a 66% fora
  do nominal → exigem reamostragem síncrona (o **interpolador** do usuário, que zera o
  vazamento). Com entalhes no sinal, as harmônicas medidas incluem o conteúdo dos próprios
  entalhes (5ª −58%, 13ª +156% em relação ao fundo) — correto para medir distorção,
  inadequado para semear o banco.
- O interpolador do usuário (passagem por zero + Lagrange cúbico) foi avaliado:
  passagem por zero quebra com 40 dB (cruzamentos múltiplos); o Lagrange tem sobressinal
  de ±6,2% nas bordas → viés de +4% na profundidade se usado antes do detector. Seu lugar
  é o ramo de medição harmônica, em espera.
- **Espaço de fase** (artigo de Kolenc, EuroCon 2013): o par x(n), x(n−T/4) forma um
  círculo; o detector deles testa o raio. O nosso usa o mesmo par só para dimensionar o
  limiar. O ângulo de um único ponto do círculo é a fase, mas com erro ~200× maior que o
  da SWRDFT no nosso sinal (harmônicas e entalhes distorcem o ponto).

---

## 4. Falsos positivos com ruído baixo e a regra da secante

**O defeito.** No pico da onda, a fundamental quase não varia, e o limiar da regra
"variação" cai para o piso 5σ. As harmônicas continuam variando (~0,6 V por amostra com
4% de THD). Com ruído baixo (65 dB, σ ≈ 0,27 V), surgem eventos de 1 a 2 amostras e ~1 V.
É **sistemático** (piora quanto menos ruído), não aleatório.

**Variantes testadas** (bancada: 65 dB e 7 frequências; 45, 40, 35 dB a 60 Hz; 10% de THD
quase sem ruído):

| Variante | Resultado |
|---|---|
| Atual ("variação") | 8 falsos em 2 772 entalhes a 65 dB; **542 falsos** em 594 com 10% THD sem ruído |
| "Passo" (último salto real como salto esperado) | sem falsos, mas perde entalhes a 40 dB e até a 65 dB — descartada |
| Harmônicas por FFT no limiar | perde 17 entalhes a 45 dB (a FFT inclui os entalhes) — descartada |
| Inovação com 2 amostras | 9 falsos a 40 dB (ruído da previsão 2,45σ) — descartada |
| **Secante de 4 amostras, margem 4** | **0 falsos em todos os casos; idêntica à atual de 60 a 40 dB**; a 35 dB perde 101 (atual 50) |

**Validação da secante** (cópia de trabalho, padrão `'Regra','secante','Cinov',4`):
testes 1, 2 (60–40 dB), 3 (0–8%) e 4 **idênticos**; teste 3 a 10%: 1 falso → 0 (OK);
teste 2 a 35/30 dB: 102/197 perdidos (atual 51/158), mas 0 falsos (atual 1/7); piloto:
caso 6 sem o falso (pior ângulo 11,4° → 2,5°), os outros 9 idênticos.

**Decisão do usuário**: manter a pasta como está por enquanto. Argumento a considerar: se
os registros reais tiverem ruído ≥ ~60 dB, o defeito aparece com frequência e vale adotar;
se forem mais ruidosos (≤ ~55 dB), a limitação não se manifesta e documentá-la basta.

**Como a regra funciona.** Previsão x̂(i) = xref(i−1) + [xref(i−1) − xref(i−5)]/4; desvio =
|x(i) − x̂(i)| (e o equivalente olhando a amostra seguinte); limiar = 4 × 1,62σ + 3c, com c
a curvatura local. O limiar fica quase constante ao longo da onda (1,7 a 2,5 V a 65 dB,
contra 1,4 a 13,1 V na regra atual). Nas 2m+1 = 9 amostras após uma reancoragem forçada,
usa a regra "variação" (a previsão ainda veria a reconstrução antiga — sem essa proteção,
a reconstrução divergia).

**Código do protótipo** — trecho dentro do `switch p.Regra` no laço do `notch_detector.m`
(opções novas: `'Regra'` ∈ {`'variacao'`, `'secante'`}, `'Cinov'` = 4, `'Msec'` = 4;
o `notch_analyze.m` repassa `'Regra'` e `'Cinov'` ao detector):

```matlab
        case 'secante'       % previsao pela inclinacao da secante de m amostras
            m  = p.Msec;
            % ruido da previsao: x(i) - (1+1/m) xref(i-1) + (1/m) xref(i-1-m)
            sp = sqrt(1 + (1 + 1/m)^2 + 1/m^2);
            % erro de modelo: curvatura local (segunda diferenca de passo m)
            c  = abs(xref(i-1) - 2*xref(i-1-m) + xref(i-1-2*m))*(m + 1)/(2*m^2);
            epsilon(i) = p.Cinov*sp*sigma + Arel*c;
            if desdeAncora <= 2*m + 1
                d3 = k1*abs(xref(i-N4)) + k2*abs(xref(i-N2));
                epsilon(i) = Arel*d3 + p.Cnoise*sigma;
                dprev = abs(x(i) - xref(i-1));
            else
                dprev = abs(x(i) - (xref(i-1) + (xref(i-1) - xref(i-1-m))/m));
            end
            if desdeAncora <= 2*m + 1
                dnext = abs(x(i+1) - x(i));
            else
                dnext = abs(x(i+1) - (x(i) + (x(i) - xref(i-m))/m));
            end
```

Contador da proteção de reancoragem (antes do laço: `desdeAncora = inf;`), no fim de cada
iteração:

```matlab
    if ~isCore && run < p.MaxRun
        % ... reconstrucao pelo banco ...
        run = run + 1;
        desdeAncora = desdeAncora + 1;
    else
        xref(i) = x(i);
        forcado = ~isCore;    % aceita sem ser nucleo = reancoragem
        if forcado, desdeAncora = 0; else, desdeAncora = desdeAncora + 1; end
        run = 0;
    end
```

---

## 5. Pareamento do ângulo (correção pendente)

A Tabela 2B e o `mc_uma_rodada.m` ligam cada evento ao entalhe verdadeiro de centro mais
próximo a até 1,5 ms — sem exigir sobreposição e sem limite de um evento por entalhe.
No piloto, um falso de 2 amostras a 32 amostras de um entalhe virou "erro de localização
de 11°". Correção: o `parear_eventos.m` devolver os pares que forma (saída nova, sem mudar
as existentes) e o ângulo ser avaliado só nesses pares. Com a cadeia atual e os testes
atuais, a Tabela 2B não mudaria (não há falsos); importa quando houver falsos.

---

## 6. Estudo de Monte Carlo (planejado)

**Grade**: frequências `(550:650)/10` (101 valores) × SNR `[65 55 45]` × 200 sinais =
60 600 simulações. Sugestão em discussão: acrescentar 40 dB.

**Semente única e reproduzível**:
`semente = (iRuido-1)*101*200 + (iFreq-1)*200 + iSinal` (de 1 a 60 600).

**Guardar**: uma linha por sinal (não os sinais — regeneráveis pela semente), um `.mat` por
combinação frequência × ruído (`f55.0_snr45.mat`) para poder retomar, consolidação final
em `.mat` e `.csv`, e um `struct` de configuração (parâmetros fixos, data, versão do
MATLAB, hash dos arquivos do código).

**Arquivos sugeridos**: `mc_config.m`, `mc_uma_rodada.m` (núcleo, abaixo), `mc_rodar.m`
(laços, retomada, `parfor`), `mc_analisar.m` (média, desvio, P5/P95, RMS por combinação;
gráficos de erro × frequência, uma curva por SNR).

**Decisões em aberto**: o que varia entre os 200 sinais (hoje só o ruído; sugerido também a
fase inicial da rede, o que exige mudar o gerador); duração (0,2 s); regra de decisão
(seção 4); pareamento (seção 5).

**Tempo**: 3,6 s por caso no Octave (~61 h no total). Duas otimizações sem mudar
resultados: o `notch_analyze` devolver a SWRDFT já calculada (hoje ela roda duas vezes) e
o `fase_swrdft` usar a recursão pré-alocada → ~1 s por caso. Fazer um piloto no MATLAB
do usuário para medir.

**Piloto (10 casos sorteados, regra atual)**: todos com a frequência pela SWRDFT (erro
≤ 0,0015 Hz); 66/66 entalhes em todos; área P90 1,9–3,4%; profundidade P90 5,5–6,9% a
45 dB (viés conhecido); ângulo pior caso 3,5–3,6° a 56 Hz (esperado, fora de 57,75–62,75);
**caso 6** (57,2 Hz, 65 dB, semente da fórmula): 1 falso de 2 amostras e 1,1 V no pico.

**Protótipo `mc_uma_rodada.m`** (usa o pareamento antigo de 1,5 ms no ângulo — corrigir
conforme a seção 5 antes de usar):

```matlab
function r = mc_uma_rodada(fReal, snr, semente, cfg)
% MC_UMA_RODADA
%
% Uma simulacao do estudo de Monte Carlo: gera um sinal, roda a cadeia
% completa e compara tudo com a verdade de campo.  Devolve uma linha de
% resultados (struct com campos escalares).
%
%   r = mc_uma_rodada(fReal, snr, semente, cfg)
%
%   fReal    frequencia real da rede [Hz]
%   snr      relacao sinal-ruido [dB]
%   semente  semente do ruido (define o sinal; o mesmo trio fReal, snr,
%            semente gera sempre o mesmo sinal)
%   cfg      parametros fixos: Fs, f0, nCiclos, Vll, alphaDeg, muDeg,
%            Ls, Lt, thd

t0 = tic;

% ---------- sinal ----------
sinal = {'Modo', 'conversor', 'Fs', cfg.Fs, 'f0', cfg.f0, 'nCiclos', cfg.nCiclos, ...
         'Vll', cfg.Vll, 'Grandeza', 'fase-fase', 'alphaDeg', cfg.alphaDeg, ...
         'muDeg', cfg.muDeg, 'Ls', cfg.Ls, 'Lt', cfg.Lt, 'Bits', [], ...
         'SNRdb', snr, 'Harmonicos', harmonicos_thd(cfg.thd), ...
         'DesvioFreqHz', fReal - cfg.f0, 'Semente', semente};
[x, ~, truth, meta] = gerar_sinal_teste(sinal{:});

% ---------- cadeia completa (estima a frequencia pela SWRDFT) ----------
R = notch_analyze(x, cfg.Fs, cfg.f0, 'Vll', cfg.Vll);

% ---------- deteccao e medidas (como avaliar_cenario, uma semente) ----------
tC = (R.detector.iInicio + R.detector.Janela)/cfg.Fs;     % fim do aquecimento
tr = truth([truth.tInicio] > tC);
ev = R.eventos;
if ~isempty(ev), ev = ev([ev.tInicio] > tC); end
P = parear_eventos(ev, tr);

% ---------- frequencia e angulo pela SWRDFT ----------
F  = fase_swrdft(x, cfg.Fs, cfg.f0);
fv = F.f(F.valido);
eA = R.eventos(~[R.eventos.modeloReduzido]);
tc = 0.5*([eA.tInicio] + [eA.tFim]);
ic = round(tc*cfg.Fs) + 1;
ok = F.valido(ic)';
tcOk   = tc(ok);
angMed = mod(rad2deg(F.theta(ic(ok))'), 360);
eLeit  = difang(angMed, mod(360*meta.fReal*tcOk + 30, 360));   % leitura

ent = truth(strcmp({truth.tipo}, 'entalhe'));
tv  = 0.5*([ent.tInicio] + [ent.tFim]);
desl = [];  eTot = [];  semPar = 0;
for k = 1:numel(tcOk)
    [d, j] = min(abs(tv - tcOk(k)));
    if d <= 1.5e-3
        desl(end+1) = (tcOk(k) - tv(j))*cfg.Fs;                          %#ok<AGROW>
        eTot(end+1) = difang(angMed(k), mod(360*meta.fReal*tv(j) + 30, 360)); %#ok<AGROW>
    else
        semPar = semPar + 1;
    end
end

% ---------- linha de resultados ----------
r.fReal     = fReal;
r.snr       = snr;
r.semente   = semente;
r.fEst      = R.frequencia.estimada;
r.erroF     = R.frequencia.estimada - fReal;
r.rmsF      = sqrt(mean((fv - fReal).^2));
r.usouSWRDFT= strcmp(R.frequencia.fonte, 'SWRDFT');
r.nVerd     = P.nVerd;
r.nDet      = P.nDet;
r.falsos    = P.nFalsos;
r.perdidos  = P.nPerdidos;
[r.profMed, r.profP90] = resumo(P.eProf);
[r.largMed, r.largP90] = resumo(P.eLarg);
[r.areaMed, r.areaP90] = resumo(P.eArea);
r.leitMed   = mean(eLeit);
r.leitRms   = sqrt(mean(eLeit.^2));
r.leitPior  = max(abs(eLeit));
r.locMed    = mean(desl);
r.locPior   = max(abs(desl));
r.totMed    = mean(eTot);
r.totRms    = sqrt(mean(eTot.^2));
r.totPior   = max(abs(eTot));
r.semPar    = semPar;
r.tempo     = toc(t0);
end

function [med, p90] = resumo(v)
if isempty(v), med = NaN; p90 = NaN; return; end
a = sort(abs(v(:)));
med = median(v);
p90 = a(max(1, ceil(0.9*numel(a))));
end
```

---

## 7. Detector alternativo do usuário: `notch_swrdbscan` (avaliado, não adotado)

SWRDFT com várias harmônicas, contínua, como previsão um passo à frente ("o último ciclo
repetido"); resíduo r e Δr; regra de densidade inspirada no DBSCAN (menos de 5 vizinhos
normais num raio de 3 desvios → anomalia); aprende o "normal" nos 3 primeiros ciclos;
durante o entalhe alimenta a SWRDFT com a previsão; fim após 3 amostras de recuperação.

| Teste (61 440 S/s, 216 entalhes) | swrdbscan | Regra atual | Secante |
|---|---|---|---|
| 65 dB, THD 4%, 60 Hz | 0 falsos | 0 | 0 |
| 65 dB, THD 4%, 57,2 Hz | **124 falsos** | 0 | 0 |
| THD 10%, quase sem ruído, 60 Hz | 0 | **72 falsos** | 0 |

Com entalhes também no aquecimento (o caso real de um conversor): 108 eventos para 54
entalhes e profundidade −64%. Motivos: supõe aquecimento sem entalhes; previsão com ciclo
de tamanho fixo (frequência nominal); exige Fs/f0 inteiro (não roda a 62,5 kS/s).
Usar só a SWRDFT multi-harmônica como referência também não serve aqui: os entalhes de 6
pulsos têm espectro nas mesmas ordens 6k±1 das harmônicas de fundo; o banco separa os dois
pelo **tempo** (semeia fora dos entalhes), a SWRDFT não consegue separar pela frequência.

---

## 8. Pastas e arquivos legados (fora da pasta atual)

- `notching_final/`: cadeia anterior para um único sinal (`analisar_notching.m` a
  100 kS/s, `notch_report.m`, `notch_plot.m`); sem a integração da SWRDFT.
- `investigacao_filtro/`, `notching_testes/`: scripts das investigações antigas.
- `notchlab_toolkit/`: toolkit em Python e guia em PDF.
- `diagramas_escalabilidade/`: PNGs dos diagramas de blocos (escada, cadeia com SWRDFT,
  com molduras indicando o arquivo de cada cálculo) e prévias dos gráficos do teste 4.
- Documento explicativo em linguagem simples (Claude Doc): "Medição de entalhes na rede
  elétrica — explicado de forma simples".
