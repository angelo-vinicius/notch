# Detecção e medição de entalhes (notching) — contexto do projeto

> Leia este arquivo inteiro antes de qualquer tarefa. O histórico detalhado — tabelas de
> resultados, decisões e código de protótipos que não estão na pasta — está em
> `HISTORICO_PROJETO.md`. Consulte-o antes de propor mudanças na cadeia ou no estudo de
> Monte Carlo.

## Como trabalhar neste projeto

- **Responda em português do Brasil**, com explicações claras e passo a passo. O usuário
  quer entender o porquê de cada coisa, não só receber código.
- **Meça antes de afirmar.** Separe sempre o que foi verificado (rodado, com números) do
  que é suposição. Se um resultado não foi testado, diga isso.
- **Nada de remendos.** Ataque causas, não sintomas. Uma mudança na cadeia só é adotada
  depois de rodar os testes 1 a 4 **antes e depois**, lado a lado, e confirmar que nada
  piorou na faixa de operação.
- **A pasta está como o usuário quer.** Não altere arquivos sem pedido explícito. Para
  experimentar, trabalhe numa cópia e mostre a comparação.
- **`SWRDFT.m` é do usuário: nunca altere.** Está salvo em ISO-8859 (Latin-1); os avisos
  de codificação no Octave são inofensivos.
- **Arquivos `.m` só em ASCII** (sem acentos, inclusive nos `fprintf`), para funcionar no
  MATLAB e no Octave.
- **Sem funções locais dentro de scripts.** O MATLAB exige que fiquem no fim; o Octave,
  antes do uso. Funções auxiliares vão em arquivos próprios.
- **O usuário roda no MATLAB.** O gerador de números aleatórios do MATLAB difere do do
  Octave: com a mesma semente, o ruído não é idêntico, e os números com ruído podem
  diferir um pouco dos registrados aqui (os sem ruído batem exatamente).
- Ao propor gráficos num ambiente sem interface gráfica, gere uma prévia e avise que a
  figura do MATLAB não foi conferida visualmente.

## Objetivo

Um método para **detectar e medir entalhes de comutação** (IEEE 519) na tensão da rede,
causados por conversores a tiristor. Para cada entalhe: localização, profundidade,
largura, área e ângulo na onda; para o registro: frequência real da rede e tipo de
conversor. A validação é feita com **sinais simulados com verdade de campo** (o gerador
sabe a resposta certa), numa "escada" de testes que acrescenta uma dificuldade por vez.

## Arquivos da pasta `notching_escalabilidade`

| Grupo | Arquivo | Função |
|---|---|---|
| Testes | `teste_1_senoide_limpa.m` | senoide com entalhes, sem perturbação |
| | `teste_2_ruido.m` | + ruído, SNR de 60 a 25 dB |
| | `teste_3_harmonicos.m` | + harmônicas, THD de 0 a 10%, ruído fixo de 55 dB |
| | `teste_4_fase_swrdft.m` | + rede fora de 60 Hz: frequência e ângulo pela SWRDFT (5 seções) |
| Cadeia | `gerar_sinal_teste.m` | sinal simulado (ponte de 6 pulsos) + verdade de campo |
| | `notch_analyze.m` | orquestra: estima a frequência (SWRDFT), chama o detector, mede, classifica |
| | `notch_detector.m` | detector causal amostra a amostra, banco de ressonadores |
| SWRDFT | `SWRDFT.m` | DFT de janela deslizante recursiva — **do usuário, não alterar** |
| | `fase_swrdft.m` | frequência f(i) e fase instantânea θ(i) a partir da SWRDFT |
| | `swrdft_bloco.m` | mesma recursão, por blocos com estado (registros longos); idêntica ao `SWRDFT.m` |
| | `sinal_bloco.m` | gera um trecho do sinal (registros longos); idêntico ao gerador |
| Avaliação | `avaliar_cenario.m` | roda a cadeia com várias sementes e compara com a verdade |
| | `parear_eventos.m` | pareia eventos detectados × entalhes verdadeiros (sobreposição) |
| | `escada_util.m` | critérios de veredito, cabeçalhos e linhas de tabela |
| | `difang.m` | diferença angular no intervalo [−180°, 180°) |
| Apoio | `harmonicos_thd.m` | harmônicas 5, 7, 11, 13 com pesos ~1/h para um THD pedido |
| | `descrever_sinal.m` | descreve e desenha o sinal testado |
| Gráficos | `plot_ciclo_fase.m` | ciclo trigonométrico do ângulo (raio = tempo) + erro × tempo |
| | `plot_erro_frequencia.m` | erro RMS da frequência [%] × frequência da rede |
| | `plot_erro_fase.m` | erro RMS do ângulo [graus] × frequência da rede |
| Docs | `LEIA_ME.txt`, `Metodologia_testes_1_a_3.pdf` | guia e metodologia dos testes 1 a 3 |

## O sinal de teste (parâmetros padrão)

- Ponte tiristorizada de **6 pulsos**, rede de **480 V** fase-fase, **60 Hz** nominal.
- **Taxa de amostragem: 62,5 kS/s** → 1 041,67 amostras por ciclo (não inteiro — importa
  para a SWRDFT, cuja janela é N = 1042).
- α = 35° (disparo), μ = 9° (sobreposição), L_s = 30 µH, L_t = 70 µH → ρ = 30%.
- Tensão fase-fase v_ab: **6 entalhes por ciclo** — 2 profundos (~141 V, 20,8% do pico)
  e 4 rasos (~71 V); largura 417 µs ≈ 26 amostras.
- Registros de 12 ciclos (0,2 s) nos testes 1 a 3 e nas seções 2 e 3 do teste 4.
- Sem quantização (pertence ao instrumento, assunto em espera).
- Ângulo verdadeiro de v_ab num instante t: `mod(360*f_real*t + 30, 360)`, porque
  v_ab = √3·Vp·sen(ωt + 30°).
- O gerador só cria entalhes a partir do ciclo 0: o primeiro ciclo tem um entalhe a menos
  (o da comutação anterior ao registro). Cálculos de "verdade" espectral devem usar só
  ciclos completos.

## A cadeia (`notch_analyze` → `notch_detector`)

1. **Frequência real pela SWRDFT** (`fase_swrdft`): fase da fundamental a cada amostra;
   f(i) = Fs/N + [φ(i) − φ(i−N)]·Fs/(2πN); válida após 2 janelas. A cadeia usa a **média**
   das estimativas válidas. Salvaguardas: com menos de 1 ciclo de estimativas válidas, ou
   fora de ±5 Hz do nominal (`FaixaFrequencia`), usa 60 Hz e avisa.
   Opção `'EstimarFrequencia', false` restaura o comportamento antigo (60 Hz fixo).
2. **Fundamental** por projeção na frequência usada: amplitude V1 e fase φ1.
3. **Detector** amostra a amostra, com a frequência usada:
   - ruído σ = 1,4826·MAD(segunda diferença)/√6;
   - **regra de decisão atual ("variação")**: limiar ε = 3·(k1·|xref(i−N/4)| + k2·|xref(i−N/2)|) + 5σ,
     com k1 = ωTs e k2 = ω²Ts²/2; desvios dprev = |x(i) − xref(i−1)| e dnext = |x(i+1) − x(i)|;
     aceita se ambos ≤ ε;
   - amostra aceita entra na referência; amostra marcada é **reconstruída pelo banco de
     ressonadores** (ordens 1, 5, 7, 11, 13), semeado por ajuste robusto (Tukey) em meio
     ciclo de amostras aceitas antes do entalhe, com fechamento de lacunas (< 1 ms);
   - **reancoragem**: após `MaxRun` = 1 ms de marcação contínua, força a aceitação;
   - agrupamento: amostras marcadas consecutivas = um evento; início = primeira marcada,
     fim = última. O `dnext` marca uma amostra antes do entalhe → largura com +1 amostra
     (viés fixo de ~+3,7%) e centro −0,5 amostra.
4. **Medidas** pelo resíduo xref − x: profundidade (máximo), largura (amostras/Fs), área
   (trapézio, V·µs).
5. **Ângulo da cadeia**: `powDeg = 360·f·tc + φ1` (frequência estimada + fase φ1 da
   projeção). O teste 4 mede o ângulo de outra forma, pela fase instantânea da SWRDFT.
6. **Conversor**: intervalos entre entalhes agrupados em T/6, T/12, T/18 (`infer_pulses`).
7. Resultado `R`: eventos, `R.frequencia` (nominal, estimada, usada, fonte), conversor.

## Avaliação (convenções)

- **Aquecimento** descontado: o primeiro ciclo (iInicio + meia janela) fica fora.
- **Pareamento** (`parear_eventos`): sobreposição no tempo, um evento por entalhe;
  sem par = falso; entalhe sem evento = perdido. Comparar sempre evento a evento.
- Erros em %: (medido − verdadeiro)/verdadeiro × 100. Resumos: mediana (viés), **P90** do
  erro absoluto, pior caso, **RMS**.
- **Veredito**: OK = 0 falsos/perdidos e P90 de profundidade e área ≤ 5%; ATENÇÃO =
  falsos+perdidos ≤ 2% e P90 ≤ 20%; QUEBROU = pior.
- **Ângulo**, teste 4: Tabela 2 = erro de **leitura** (fase medida × verdadeira no mesmo
  instante); Tabela 2B = erro de **localização** (centro detectado − verdadeiro, em
  amostras; 1 amostra ≈ 0,35° a 60 Hz) e erro **total** (leitura + localização).
  Diferenças angulares sempre por `difang` (caminho mais curto).
- O erro médio de ~−1° no ângulo é o deslocamento que os entalhes impõem à fase da própria
  fundamental (verdade = fonte ideal), não falha do método.

## Resultados de referência (cadeia atual, 62,5 kS/s, Octave)

- **Teste 1**: OK — 66/66, profundidade 0,0%, área +1,8%, largura +3,7%.
- **Teste 2**: OK até 50 dB; ATENÇÃO em 45 e 40 dB (detecção perfeita, profundidade
  superestimada pelo ruído; área ≤ 4,3%); QUEBROU a partir de 35 dB (piso 5σ ≈ entalhes rasos).
- **Teste 3**: OK até 8% de THD; 1 falso em 199 a 10% (ATENÇÃO).
- **Teste 4**: frequência com erro médio ≤ 0,0004 Hz de −2 a +2 Hz; ângulo com pior caso
  ≤ 2° de **57,75 a 62,75 Hz**; localização < 1 amostra; erro total RMS 1,1°, pior 2,1°;
  registro de **10 min** sem acúmulo de erro (−0,994° em todos os minutos); erro RMS da
  frequência de 0,005% (perto de 60 Hz) a 0,53% (55 Hz).

## Estado atual e pendências

1. **Falsos positivos com ruído baixo + harmônicas** (no pico da onda): a regra "variação"
   só modela a fundamental. Uma regra nova, **"secante"** (previsão pela inclinação de 4
   amostras), foi validada numa cópia: elimina os falsos e deixa os testes 1 a 4 idênticos
   na faixa de operação; perde mais entalhes só abaixo de 40 dB. **Não está na pasta** —
   o usuário decidiu manter a pasta como está; a adoção depende do ruído dos registros
   reais. Código em `HISTORICO_PROJETO.md`.
2. **Pareamento do ângulo**: a Tabela 2B associa eventos ao entalhe de centro mais próximo
   a até 1,5 ms; deveria usar os pares do `parear_eventos` (que precisaria devolvê-los).
   Afeta só a avaliação, não o método.
3. **Estudo de Monte Carlo** planejado: 101 frequências (55,0 a 65,0 Hz, passo 0,1) ×
   SNR {65, 55, 45} dB × 200 sinais = 60 600 casos. Piloto de 10 casos feito.
   Plano, decisões em aberto e o protótipo `mc_uma_rodada.m` em `HISTORICO_PROJETO.md`.
4. **Ângulo da cadeia** ainda é `360·f·tc + φ1`; a fase instantânea da SWRDFT é mais
   robusta para registros longos com frequência variando. Troca pequena, não feita.
5. **Em espera**: interpolador do usuário + medição de harmônicas pela SWRDFT síncrona;
   instrumento (filtro anti-aliasing, quantização); teste 5 (frequência variando no tempo).

## Como rodar

- No MATLAB, com a pasta como diretório atual: `teste_1_senoide_limpa`, `teste_2_ruido`,
  `teste_3_harmonicos`, `teste_4_fase_swrdft`.
- Pela linha de comando (se o MATLAB estiver no PATH): `matlab -batch "teste_1_senoide_limpa"`.
  No Octave: `octave --no-gui --eval "teste_1_senoide_limpa"`.
- Tempos no Octave: ~3 s, ~55 s, ~40 s; teste 4 completo ~12 min por causa do registro
  longo de 10 min. Para um teste rápido, no teste 4: `rodarLongo = false` ou reduza
  `duracaoLonga`. No MATLAB costuma ser bem mais rápido.
- O `SWRDFT.m` não pré-aloca vetores: é lento em registros longos (crescimento quase
  quadrático). Para minutos de sinal, use `swrdft_bloco.m` (resultado idêntico).
