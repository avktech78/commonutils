{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit commonutils_ilya2ik;

{$warn 5023 off : no warning about unused units}
interface

uses
  BufferedStream, ECommonObjs, gwidgetsethelper, gzstream, kcThreadPool, 
  OGLFastList, OGLFastVariantHash, SortedThreadPool, ExtSqlite3Backup, 
  ExtSqlite3DS, extsqlite3funcs, sqlitelogger, sqlitewebsession, 
  LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('commonutils_ilya2ik', @Register);
end.
