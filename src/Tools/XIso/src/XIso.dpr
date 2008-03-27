{
   xISO
   Copyright 1984, 1986, 1989, 1992, 2000, 2001, 2002
   Free Software Foundation, Inc.

   This file is part of xISO, made it by Yursoft.com

   xISO is free software; you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   Bison is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with Bison; see the file COPYING.  If not, write to the Free
   Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
   02111-1307, USA.
}


program XIso;

uses
  Forms,
  Windows,
  Messages,
  SysUtils,
  Reinit,
  ufrm_Main in 'ufrm_Main.pas' {Form1},
  uxiso in 'uxiso.pas',
  uxisomaker in 'uxisomaker.pas',
  Textos in 'Textos.pas',
  ufrm_Language in 'ufrm_Language.pas' {Form2},
  progreso in 'progreso.pas' {Form3},
  GenerarXDFS in 'GenerarXDFS.pas',
  Grabacion in 'Grabacion.pas' {Form4},
  CreacionISO in 'CreacionISO.pas',
  FormCreacionISO in 'FormCreacionISO.pas' {Form5},
  ProgresoCreacionISO in 'ProgresoCreacionISO.pas',
  xisomakerv3 in 'xisomakerv3.pas',
  xisomakerv2 in 'xisomakerv2.pas';

{$R *.res}

var
  Parametro, CarpetaParametro, ImagenParametro, S: string;
  i, j: integer;
  MensajesActivados: Boolean;
  Idioma: LANGID;
begin
  Idioma := GetUserDefaultLangID();
  if (word(Idioma and $000F)) = LANG_SPANISH then
  begin
          //SetLocalOverrides(ParamStr(0),'esp');
    if LoadNewResourceModule(LANG_SPANISH) <> 0 then
      ReinitializeForms;
  end
  else
  begin
          //SetLocalOverrides(ParamStr(0),'enu');
    if LoadNewResourceModule(LANG_ENGLISH) <> 0 then
      ReinitializeForms;
  end;

  MensajesActivados := True;
  for j := 0 to ParamCount - 1 do
    if Copy(ParamStr(j), 1, 2) = '-n' then
    begin
      MensajesActivados := False;
      Break;
    end;
  for i := 0 to ParamCount - 1 do
  begin
    Parametro := Copy(ParamStr(i), 1, 2);

    if Parametro = '-e' then
    begin
      OrigenDatos := OD_IMAGEN;
      if not AbrirXISO(ParamStr(i + 1)) then
      begin
        if MensajesActivados then
          MessageBox(Application.Handle, PChar(rcEngImagenNoXBOX), PChar('xISO'), MB_ICONWARNING or MB_OK);
        Exit;
      end;
      NombreImagen := ParamStr(i + 1);

      CarpetaParametro := '';
      for j := 0 to ParamCount - 1 do
        if Copy(ParamStr(j), 1, 2) = '-f' then
          CarpetaParametro := ParamStr(j + 1);
      if CarpetaParametro = '' then
      begin
        if MensajesActivados then
          MessageBox(Application.Handle, PChar(rcEngCarpetaExtError), PChar('xISO'), MB_ICONWARNING or MB_OK);
        Exit;
      end;

      if not DirectoryExists(CarpetaParametro) then
        ForceDirectories(CarpetaParametro);

      if not DirectoryExists(CarpetaParametro) then
      begin
        if MensajesActivados then
          MessageBox(Application.Handle, PChar(rcEngCarpetaExtError), PChar('xISO'), MB_ICONWARNING or MB_OK);
        Exit;
      end;

      ExtraerCD(0, 0, 0, 0, CarpetaParametro);
      if MensajesActivados then
        MessageBox(Application.Handle, PChar(rcEngFinExtraccion), PChar('xISO'), MB_ICONINFORMATION or MB_OK);
      Exit;
    end
    else
      if Parametro = '-m' then
      begin
        CarpetaParametro := '';
        for j := 0 to ParamCount - 1 do
          if Copy(ParamStr(j), 1, 2) = '-f' then
            CarpetaParametro := ParamStr(j + 1);
        if CarpetaParametro = '' then
        begin
          if MensajesActivados then
            MessageBox(Application.Handle, PChar(rcEngCarpetaExtError), PChar('xISO'), MB_ICONWARNING or MB_OK);
          Exit;
        end;

        if not DirectoryExists(CarpetaParametro) then
          ForceDirectories(CarpetaParametro);

        if not DirectoryExists(CarpetaParametro) then
        begin
          if MensajesActivados then
            MessageBox(Application.Handle, PChar(rcEngCarpetaExtError), PChar('xISO'), MB_ICONWARNING or MB_OK);
          Exit;
        end;

        CrearImagen(CarpetaParametro, ParamStr(i + 1));
                //MessageBox(Application.Handle, PChar(rcFinCreacion), PChar('xISO'), MB_ICONINFORMATION or MB_OK);
        Exit;
      end
      else
        if Parametro = '-d' then
        begin
          CarpetaParametro := '';
          for j := 0 to ParamCount - 1 do
            if Copy(ParamStr(j), 1, 2) = '-f' then
              CarpetaParametro := ParamStr(j + 1);
          if CarpetaParametro = '' then
          begin
            if MensajesActivados then
              MessageBox(Application.Handle, PChar(rcEngCarpetaExtError), PChar('xISO'), MB_ICONWARNING or MB_OK);
            Exit;
          end;

          if not DirectoryExists(CarpetaParametro) then
            ForceDirectories(CarpetaParametro);

          if not DirectoryExists(CarpetaParametro) then
          begin
            if MensajesActivados then
              MessageBox(Application.Handle, PChar(rcEngCarpetaExtError), PChar('xISO'), MB_ICONWARNING or MB_OK);
            Exit;
          end;

          ImagenParametro := ParamStr(i + 1);
          if ImagenParametro[Length(ImagenParametro)] = '\' then
            ImagenParametro[Length(ImagenParametro)] := ' ';

          ImagenParametro := ExtractFileName(ImagenParametro) + '.xiso';

          CrearImagen(CarpetaParametro, ImagenParametro);
                //MessageBox(Application.Handle, PChar(rcFinCreacion), PChar('xISO'), MB_ICONINFORMATION or MB_OK);
          Exit;
        end
        else
          if Parametro = '-x' then
          begin
            OrigenDatos := OD_IMAGEN;
            if not AbrirXISO(ParamStr(i + 1)) then
            begin
              if MensajesActivados then
                MessageBox(Application.Handle, PChar(rcEngImagenNoXBOX), PChar('xISO'), MB_ICONWARNING or MB_OK);
              Exit;
            end;
            NombreImagen := ParamStr(i + 1);

            CarpetaParametro := '';
            for j := 0 to ParamCount - 1 do
              if Copy(ParamStr(j), 1, 2) = '-f' then
                CarpetaParametro := ParamStr(j + 1);
            if CarpetaParametro = '' then
            begin
              if MensajesActivados then
                MessageBox(Application.Handle, PChar(rcEngCarpetaExtError), PChar('xISO'), MB_ICONWARNING or MB_OK);
              Exit;
            end;


            if lowercase(ExtractFileExt(ExtractFileName(NombreImagen))) = '.xiso' then
              S := Copy(NombreImagen, 1, Length(NombreImagen) - 4)
            else
              S := NombreImagen;

            CarpetaParametro := ExtractFilePath(CarpetaParametro) + Trim(ChangeFileExt(ExtractFileName(NombreImagen), ' ')) + '\';

            if not DirectoryExists(CarpetaParametro) then
              CreateDir(CarpetaParametro);

            if not DirectoryExists(CarpetaParametro) then
            begin
              if MensajesActivados then
                MessageBox(Application.Handle, PChar(rcEngCarpetaExtError), PChar('xISO'), MB_ICONWARNING or MB_OK);
              Exit;
            end;

            ExtraerCD(0, 0, 0, 0, CarpetaParametro);
            if MensajesActivados then
              MessageBox(Application.Handle, PChar(rcEngFinExtraccion), PChar('xISO'), MB_ICONINFORMATION or MB_OK);
            Exit;
          end;
  end;

  Application.Initialize;
  Application.Title := 'xISO 1.1.5';
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.

