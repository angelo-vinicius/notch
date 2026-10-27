function x = sinal_bloco(t, p)
% SINAL_BLOCO
%
% Trecho do sinal de teste -- tensao fase-fase v_ab de uma ponte de 6 pulsos,
% com harmonicos de fundo --, calculado SO para os instantes t pedidos.
%
%   x = sinal_bloco(t, p)
%
%   t : instantes [s], igualmente espacados (um bloco do registro)
%   p : struct com os campos
%         Vll       tensao fase-fase eficaz [V]
%         fReal     frequencia real da rede [Hz]
%         alphaDeg  angulo de disparo [graus]
%         muDeg     angulo de sobreposicao [graus]
%         Ls, Lt    indutancias de fonte e de isolamento [H]
%         H         harmonicos, como em harmonicos_thd.m ([] = nenhum)
%
% POR QUE EXISTE
%   gerar_sinal_teste.m monta o registro inteiro de uma vez.  Para minutos
%   de sinal isso nao cabe na memoria: 10 min a 62,5 kS/s sao 37,5 milhoes
%   de amostras, 300 MB por vetor, e o gerador usa varios.  Esta funcao
%   aplica a MESMA fisica so ao trecho pedido, e o registro e gerado bloco
%   a bloco.  O ruido NAO e incluido aqui; e somado por quem chama.
%
% EQUIVALENCIA
%   Para o mesmo trecho, reproduz gerar_sinal_teste (modo conversor,
%   fase-fase, sem ruido e sem quantizacao) com diferenca da ordem de
%   1e-13 V.  O teste 4 confere isso antes de usar esta funcao.

t  = t(:);
w  = 2*pi*p.fReal;
Vp = sqrt(2)*p.Vll/sqrt(3);
fase = @(k) (k == 2)*(-2*pi/3) + (k == 3)*(2*pi/3);
e  = @(k, tt) Vp*sin(w*tt + fase(k));

x = e(1, t) - e(2, t);                          % v_ab sem entalhes

rho   = p.Ls/(p.Ls + p.Lt);
alpha = p.alphaDeg*pi/180;
mu    = p.muDeg*pi/180;
comm  = [30 3 1; 90 2 3; 150 1 2; 210 3 1; 270 2 3; 330 1 2];  % angulo, sai, entra

Fs  = 1/(t(2) - t(1));
i0g = round(t(1)*Fs);                           % indice global da 1a amostra (base 0)
% ciclos que tocam o bloco; a partir do ciclo 0, como no gerador original
c0 = max(0, floor(w*t(1)/(2*pi)) - 1);
c1 = ceil(w*t(end)/(2*pi)) + 1;

for cyc = c0:c1
    for r = 1:6
        th0 = comm(r,1)*pi/180 + 2*pi*cyc;
        tS  = (th0 + alpha)/w;
        tE  = (th0 + alpha + mu)/w;
        a = ceil(tS*Fs)  - i0g + 1;             % mesma regra de amostras do
        b = floor(tE*Fs) - i0g + 1;             % gerador original
        a = max(a, 1);  b = min(b, numel(t));
        if b < a, continue; end
        k  = a:b;
        io = comm(r,2);  ii = comm(r,3);
        dH = rho*(e(ii, t(k)) - e(io, t(k)))/2;
        dva = (io == 1)*dH - (ii == 1)*dH;
        dvb = (io == 2)*dH - (ii == 2)*dH;
        x(k) = x(k) + dva - dvb;
    end
end
for q = 1:size(p.H, 1)
    x = x + sqrt(2)*p.Vll*p.H(q,2)*sin(p.H(q,1)*w*t + p.H(q,3));
end
end
