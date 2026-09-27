function [] = Init_Memory()
Mbits = 32;  % Bits parte entera
Fbits = 0;  % Bits parte fraccional
q_rom = 16; % Tamaño datos de la rom

%tanh
freq = logspace(3,6,q_rom);
Datos = (freq*2^32)/125e6;
Datos_fi = fi(Datos,0,Mbits,Fbits);
fid = fopen('freq_log_reducido2.dat','wb');

for x = 1:q_rom
    if (freq(x)>=40)
        idea=x;
        break
    end
end
for x = 1:q_rom
    if (freq(x)>=40)
        fprintf(fid,'@%x\n',(x-idea));
        fprintf(fid,'%s\n',hex(Datos_fi(x)));
    end
end


fclose(fid);


end 