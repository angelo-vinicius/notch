function H = harmonicos_thd(thd)
% HARMONICOS_THD
%
% Monta a matriz de harmonicos de fundo para gerar_sinal_teste, com a
% distorcao harmonica total pedida.
%
%   H = harmonicos_thd(thd)
%
%   thd : distorcao harmonica total, em fracao (0.04 = 4 %)
%   H   : matriz [ordem amplitude_pu fase_rad], uma linha por harmonico,
%         pronta para gerar_sinal_teste(..., 'Harmonicos', H).
%         Vazia quando thd = 0.
%
% Ordens usadas: 5a, 7a, 11a e 13a -- as caracteristicas de conversores de
% 6 pulsos (6k +/- 1), que dominam uma rede industrial.  As amplitudes
% decrescem aproximadamente com 1/h e sao escaladas para que a raiz da soma
% dos quadrados seja exatamente o THD pedido.

ordens = [5 7 11 13];
pesos  = [1 1/1.4 1/2.2 1/2.6];
fases  = 0.3*(1:4);

if thd <= 0
    H = [];
    return
end

amp = pesos/norm(pesos)*thd;
H = [ordens' amp' fases'];
end
