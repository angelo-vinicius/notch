%% Método de decomposição de sinais variantes no tempo baseado na
%% DFT-Sliding Window ("Time-Varying Power Harmonic Decomposition using
%% Sliding-Window DFT")

function [A, Ph, yh] = SWRDFT(x,f0,Nppc,h)                                 % Função para Decomposição

fs = Nppc*f0;                                                              % Frequência de Amostragem
Ts = 1/fs;                                                                 % Período de amostragem
w0 = 2*pi*f0/fs;                                                           % Normalização da frequência fundamental

for t = 0:h                                                                % Variável de 0 (componente DC) até h (último harmônico)
    [A(:,t+1), Ph(:,t+1), yh(:,t+1)] = swr_dft(x,Nppc,t);                  % Link para função de decomposição
end
end

function [A, Ph, yh] = swr_dft(x,Nppc,h)

Ych_0 = 0; Ysh_0 = 0;                                                      % Condições iniciais de Ysh(n-1) e Ych(n-1)

s1_0 = 0; s2_0 = 1;                                                        % Condições iniciais do gerador de senos e cossenos


% s1_0 = 0; s2_0 = 1;
N = length(x);
w0 = 2*pi/Nppc;

seno = sin(w0*h);
cosseno = cos(w0*h);

for i = 1:N;
    
       
    s1 = cosseno*s1_0 + seno*s2_0;
    s2 = -seno*s1_0 + cosseno*s2_0;
    
    s11(i,1) = s1;
    s22(i,1) = s2;
    
    s1_0 = s1;
    s2_0 = s2;
    
    if i > Nppc
        x_N = x(i-Nppc);
    else
        x_N = 0;
    end
    
    Ych(i,1) = Ych_0 + (x(i)-x_N)*s2;
    Ysh(i,1) = Ysh_0 - (x(i)-x_N)*s1;
    Ych_0 = Ych(i,1);
    Ysh_0 = Ysh(i,1);
    
    if h == 0
        A(i,1) = sqrt(Ych_0^2+Ysh_0^2)/Nppc;
    else
        A(i,1) = sqrt(Ych_0^2+Ysh_0^2)*(2/Nppc);
    end
    
    Ph(i,1) = atan2(Ych_0,-Ysh_0)+h*w0;
    
   
    if h == 0
        yh(i,1) = (Ych(i)*s2-Ysh(i)*s1)/Nppc;
    else
        yh(i,1) = (Ych(i)*s2-Ysh(i)*s1)*(2/Nppc);
    end
end
end
    
        