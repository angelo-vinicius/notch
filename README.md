NOTCHING - TESTES DE ESCALABILIDADE
===================================

Escada gradual de testes da cadeia de deteccao de notching.  Cada teste
acrescenta UM ingrediente ao sinal, do caso mais simples ao mais realista.
Os testes sao independentes: cada um gera o proprio sinal e pode ser
rodado sozinho.  Basta abrir esta pasta no MATLAB e executar o teste.


TESTES
------
  teste_1_senoide_limpa.m   senoide com entalhes, sem nenhuma perturbacao
  teste_2_ruido.m           + ruido, com o SNR descendo de 60 a 25 dB
  teste_3_harmonicos.m      + harmonicos de fundo, THD de 0 a 10 %,
                            com ruido fixo de 55 dB
  teste_4_fase_swrdft.m     + rede fora de 60 Hz (-2 a +2 Hz): angulo
                            de cada entalhe medido pela SWRDFT.  A secao 4
                            simula um REGISTRO LONGO, de duracao
                            configuravel (padrao 10 min), para verificar
                            se o erro acumula ao longo do tempo.  A secao 5
                            varre a rede de 55 a 65 Hz para saber ate onde
                            o metodo funciona.  As secoes 4 e 5 rodam para
                            cada nivel de ruido das listas snrsLongo e
                            snrsVarredura (padrao 45, 55 e 65 dB), e gravam
                            as figuras em PNG na pasta graficos_teste4/
  (o teste 4 tem a opcao soRedesenhar = true: nao calcula nada e refaz
   as figuras a partir do resultado_teste_4.mat da ultima rodada;
   plot_ciclo_fase e plot_erro_frequencia sao FUNCOES de desenho: recebem
   os dados do teste 4 e nao se rodam sozinhas.)

Cada teste tem tres secoes:
  1. SINAL TESTADO   define os parametros e gera o sinal, mostrando suas
                     caracteristicas e um grafico
  2. AVALIACAO       roda a cadeia sobre o sinal, com varias sementes de
                     ruido quando ha ruido
  3. RESULTADO       tabela, veredito e resumo; grava resultado_teste_N.mat


FUNCOES (chamadas pelos testes)
-------------------------------
  Cadeia de deteccao:
    gerar_sinal_teste.m     sinal simulado de uma ponte de 6 pulsos, com
                            verdade de campo
    notch_analyze.m         organiza a analise, estima a frequencia real da
                            rede pela SWRDFT e chama o detector ja
                            sintonizado nela (opcao EstimarFrequencia)
    notch_detector.m        detecta e mede os entalhes (banco de
                            ressonadores).  Regra de decisao padrao:
                            'secante' (previsao pela inclinacao de 4
                            amostras); a regra anterior, 'variacao',
                            continua disponivel (opcao Regra)

  Apoio aos testes:
    avaliar_cenario.m       roda a cadeia num cenario, com varias sementes,
                            e compara com a verdade
    parear_eventos.m        pareia cada entalhe verdadeiro com o evento
                            detectado e calcula os erros; devolve tambem
                            os pares (parEvento), usados na avaliacao do
                            angulo
    escada_util.m           criterios de veredito, cabecalhos e linhas
    descrever_sinal.m       descreve e desenha o sinal testado
    harmonicos_thd.m        monta os harmonicos para um THD pedido

  Frequencia e fase (teste 4):
    SWRDFT.m                DFT de janela deslizante recursiva -- arquivo
                            original do projeto, sem alteracao.  Esta
                            salvo em ISO-8859; no Octave os acentos dos
                            comentarios geram avisos, sem efeito no calculo.
    fase_swrdft.m           frequencia e fase instantanea da fundamental a
                            partir da SWRDFT, com a correcao de meio ciclo
    plot_ciclo_fase.m       ciclo trigonometrico com o angulo de cada
                            entalhe (raio = tempo) e o erro ao longo do tempo
    plot_erro_frequencia.m  erro da frequencia estimada pela SWRDFT em
                            funcao da frequencia real da rede: erro RMS
                            (raiz do erro medio quadratico), em % da
                            frequencia real.  O erro medio e os valores em
                            Hz estao na Tabela 5

  Registros longos e varredura (teste 4, secoes 4 e 5):
    sinal_bloco.m           gera um trecho do sinal; o registro longo e
                            montado bloco a bloco, para caber na memoria
    swrdft_bloco.m          mesma recursao do SWRDFT.m, aplicada bloco a
                            bloco, levando o estado de um para o outro
                            (resultado identico ao SWRDFT.m; o teste confere)


SINAL COMUM AOS TESTES
----------------------
  Ponte tiristorizada de 6 pulsos, rede de 480 V e 60 Hz, 62,5 kS/s.
  Disparo alpha = 35 graus, sobreposicao mu = 9 graus, rho = 30 %.
  Tensao fase-fase: 6 entalhes por ciclo -- 2 profundos (~141 V) e
  4 rasos (~71 V) --, com 417 us de largura (~42 amostras).
  12 ciclos.  Sem quantizacao (ela pertence ao instrumento).


VEREDITOS
---------
  OK        nenhum entalhe falso ou perdido; P90 do erro de profundidade
            e de area ate 5 %
  ATENCAO   falsos + perdidos ate 2 % do total; P90 ate 20 %
  QUEBROU   pior que isso
  Os criterios ficam em escada_util.m, num lugar so.


RESULTADOS DE REFERENCIA
------------------------
  Teste 1   OK
  Teste 2   OK ate 50 dB; ATENCAO em 45 e 40 dB (deteccao perfeita,
            profundidade superestimada pelo ruido); quebra em 35 dB
  Teste 3   OK em toda a faixa, de 0 a 10 % de THD (com a regra
            'variacao', 1 evento falso a 10 %)
  Teste 4   de -2 a +2 Hz: frequencia com erro medio de ate 0,0004 Hz;
            angulo de cada entalhe com erro medio constante de cerca de
            -1 grau (efeito dos entalhes na fundamental) e pior caso de
            1,9 grau.  Tabela 2B: o detector localiza cada entalhe a menos
            de 1 amostra (0,35 grau) do centro verdadeiro; erro total do
            angulo com RMS de 1,1 grau e pior caso de 2,1 graus.  Registro de 10 min a 60,5 Hz (217 759 entalhes):
            erro medio de -0,994 grau em todos os minutos; tendencia de
            -0,0001 grau no registro inteiro -- nao acumula.
            Varredura de 55 a 65 Hz: a frequencia e medida com erro medio
            de no maximo 0,002 Hz e erro RMS de 0,003 Hz (perto de 60 Hz) a
            0,29 Hz (55 Hz); o angulo fica com pior caso dentro de 2 graus
            de 57,75 a 62,75 Hz.
            Com 45, 55 e 65 dB: registro longo com erro medio de -0,994
            grau e tendencia nula nos tres niveis (pior caso 1,25, 1,20 e
            1,19 grau); varredura com a mesma faixa (57,75 a 62,75 Hz) e o
            mesmo erro do angulo (RMS de 0,85 a 2,52 graus) nos tres; o
            ruido so aparece na frequencia perto de 60 Hz (erro RMS de
            0,0036, 0,0030 e 0,0029 Hz).  Insensivel ao ruido na faixa.

  Tempo de execucao no GNU Octave: cerca de 5 s, 20 s e 15 s nos testes
  1 a 3.  O teste 4 leva cerca de 1 min, mais ~50 s de varredura por
  nivel de ruido, mais ~1,2 s de processamento por segundo de registro
  longo, por nivel: com os 10 min padrao e tres niveis, cerca de 40 min.
  Para um teste rapido, reduza duracaoLonga, use rodarLongo = false, ou
  deixe so um nivel em snrsLongo.
  No MATLAB costuma ser bem mais rapido.


PROXIMOS DEGRAUS
----------------
  Cada novo degrau entra como um novo arquivo teste_N_*.m nesta pasta,
  seguindo a mesma estrutura de tres secoes.

TESTE COM VARIOS SINAIS DE PARAMETROS IGUAIS
--------------------------------------------
  teste_varrer_parametros.m o mesmo teste para VARIAS frequencias e
                            ruidos de uma vez (listas freqs e snrs no topo).
                            Grava o arquivo de cada combinacao e um
                            consolidado, resultados/varredura_...mat, com
                            uma linha por combinacao (pronto para graficos).
                            11 frequencias x 100 sinais: ~2 min no MATLAB.
  graficos_varredura.m      TODOS os graficos de validacao da varredura, de
                            uma vez, lendo os res_*.mat (nada e simulado):
                            erro da AREA e erro do ANGULO x frequencia, em
                            tres paineis (A: media e do menor ao maior erro,
                            em barras lado a lado por ruido; B: media do
                            valor absoluto -- na AREA, o erro RMS da
                            frequencia estimada pela SWRDFT amostra a amostra;
                            C: desvio-padrao), e erro da
                            FREQUENCIA estimada pela cadeia (media de cada
                            registro), em mHz: media e do menor ao maior
                            erro dos sinais; uma cor por ruido.
                            Opcoes no topo: snrsPlotar ([] = todos; ex.: 55),
                            grupoEscolhido, gravarFiguras (PNG, .fig e os
                            valores em resultados/graficos/).
   escolhe os niveis de ruido desenhados: [] = todos; ex.: 55 ou [45 65];
   com so alguns, o arquivo ganha o sufixo _snr<niveis>)
  rodar_conjunto.m          o miolo comum aos dois scripts: roda os N sinais
                            de um conjunto, imprime (se pedido), resume e
                            grava o arquivo.
  mc_uma_rodada.m           uma simulacao: gera o sinal, roda a cadeia e
                            compara com a verdade.  Os pares vem do
                            parear_eventos.m; os falsos ficam fora das
                            estatisticas de angulo.

REGRA DE DECISAO DO DETECTOR
----------------------------
  Padrao: 'secante'.  A regra anterior ('variacao') so modelava a
  fundamental; com ruido baixo (~65 dB) e harmonicos, gerava eventos
  falsos de 1 a 2 amostras (~1 V) nos picos da onda.  Com a 'secante',
  os testes 1 a 4 dao os mesmos resultados de 60 a 40 dB, os falsos com
  ruido baixo somem, e o teste 3 a 10 % passa a OK.  Custo: abaixo de
  40 dB, onde as duas regras ja falham, a 'secante' perde mais entalhes
  rasos (teste 2, 35 dB: 102 perdidos contra 51).  Para repetir algo com
  a regra anterior: notch_analyze(..., 'Regra', 'variacao').

FIGURA DO SINAL DE TESTE (descrever_sinal.m)
--------------------------------------------
  Os testes 1 a 4 mostram o sinal de entrada em duas partes:
  em cima, dois ciclos com os entalhes em vermelho e o angulo de cada
  entalhe na onda; embaixo, o zoom no entalhe mais profundo, com os
  NOMES das grandezas que a cadeia mede (sem valores): area A,
  profundidade d, largura w e o centro t_c, de onde sai o angulo.  O teste_varrer_parametros.m mostra a mesma figura para UM
  sinal de exemplo (opcao mostrarExemplo).
  Para desenhar essa figura para QUALQUER sinal, sem rodar a varredura:
  no teste_varrer_parametros.m, soExemplo = true, com exemploFreq,
  exemploSNR e exemploSinal no topo (segundos).  Com os mesmos parametros
  e a mesma sementeBase, o sinal e identico ao que a varredura analisa.

CICLO TRIGONOMETRICO DO TESTE 4 (plot_ciclo_fase.m)
---------------------------------------------------
  A esquerda, o angulo de cada entalhe no ciclo (raio = tempo), com
  marcadores finos e ate 360 entalhes desenhados, para separar o
  verdadeiro do medido.  A direita, um TREM DE IMPULSOS com o MODULO do
  erro do angulo de cada entalhe (|medido - verdadeiro|, em graus) no
  instante em que ele ocorreu, nos primeiros 3 ciclos; o titulo traz a
  media, o menor e o maior modulo do registro inteiro.

EVENTOS DE MODELO REDUZIDO (correcao)
-------------------------------------
  Logo apos o aquecimento, o banco de ressonadores pode reconstruir so
  com a fundamental (modelo reduzido).  Com a regra 'secante', cujo limiar
  e apertado com ruido baixo, o fim desses eventos nao era reconhecido e
  eles saturavam (~1 ms), gerando erros de area de +-8 % a 65 dB.
  Correcao no notch_detector.m: durante um evento de modelo reduzido, e
  nas 2m+1 amostras seguintes, vale a regra 'variacao'.  Resultado a 60 Hz
  e 65 dB: erro de area de -7,5..+8,2 % para +1,4..+2,2 %; testes 1 a 3 e
  erros do teste 4 identicos.  Alem disso, mc_uma_rodada.m e
  avaliar_cenario.m deixam fora da avaliacao os eventos marcados como
  modeloReduzido (e os entalhes verdadeiros que eles cobrem) -- uma
  protecao; com a correcao do detector, normalmente nao sobra nenhum.
  Os resultados da varredura gravados ANTES desta correcao precisam ser
  refeitos (rode teste_varrer_parametros de novo).

REFERENCIA DO ANGULO NA VARREDURA
---------------------------------
  O angulo medido e comparado com o da FUNDAMENTAL DO PROPRIO SINAL COM
  ENTALHES -- o que um instrumento real enxerga.  Os entalhes atrasam a
  fase da fundamental em ~1,28 grau; com esta referencia, isso nao conta
  como erro do metodo.  O erro medio fica perto de zero (+0,1 a +0,3 grau)
  e a media do |erro| tem o minimo em 60 Hz (~0,18 grau).  A referencia e
  fixa (nao ha mais opcao); os arquivos saem com o sufixo _reffund, e o
  graficos_varredura.m usa so esses (ignora, com aviso, arquivos antigos de
  outra referencia).  O teste 4 continua com a referencia da onda ideal.

INFLUENCIA DA SWRDFT NA AREA (opcao influenciaFreq, tabela na tela)
-------------------------------------------------------------------
  Com cfg.influenciaFreq = true (teste_varrer_parametros.m), cada sinal e
  analisado duas vezes: com o detector
  na frequencia ESTIMADA pela SWRDFT (a medida normal) e na frequencia
  VERDADEIRA.  A diferenca de area de cada entalhe isola o efeito da
  estimativa de frequencia sobre a area (mesmo sinal, mesmo ruido); ela e
  gravada em erros.areaFreq.  O graficos_varredura.m a imprime numa tabela
  na tela (media com sinal, menor, maior e media do |diferenca|); ela nao
  e mais desenhada.  Resultado tipico: ~0,045 %
  a 55 e 65 Hz, ~0,003 % em 60 Hz, quase zero perto de 58 Hz (onde o erro
  da frequencia estimada passa pelo zero).  Custa uma segunda passada do
  detector por sinal.
    desenhar_exemplo.m    -> opcao soExemplo do teste_varrer_parametros
  Se esses arquivos ainda estiverem na sua pasta, podem ser apagados.
