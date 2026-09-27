function [] = Init_senoide_cuarto()
Mbits = 14;  % Bits parte entera
Fbits = 13;  % Bits parte fraccional
q_rom = 1024; % Tamaño datos de la rom




Datos = sin(linspace(0,pi/2,1024));
Datos_fi = fi(Datos,0,Mbits,Fbits);
fid = fopen('sin_cuarto_2e10x14.dat','wb');


for x = 1:q_rom
    fprintf(fid,'@%x\n',(x-1));
    fprintf(fid,'%s\n',hex(Datos_fi(x)));
end
 
fclose(fid);



end 