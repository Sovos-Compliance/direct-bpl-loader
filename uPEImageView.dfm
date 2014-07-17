object Form2: TForm2
  Left = 466
  Top = 227
  Caption = 'tbu'
  ClientHeight = 468
  ClientWidth = 1061
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 16
    Top = 8
    Width = 61
    Height = 13
    Caption = 'Impots Table'
  end
  object lbl1: TLabel
    Left = 16
    Top = 232
    Width = 55
    Height = 13
    Caption = 'Exports LIst'
  end
  object TreeView1: TTreeView
    Left = 16
    Top = 32
    Width = 241
    Height = 185
    Indent = 19
    TabOrder = 0
  end
  object Button1: TButton
    Left = 272
    Top = 33
    Width = 75
    Height = 25
    Caption = 'Open'
    TabOrder = 1
    OnClick = Button1Click
  end
  object btnLoadHJPE: TButton
    Left = 272
    Top = 256
    Width = 97
    Height = 25
    Caption = 'Loald HJ'
    TabOrder = 2
    OnClick = btnLoadHJPEClick
  end
  object btnLoadSelf: TButton
    Left = 272
    Top = 64
    Width = 75
    Height = 25
    Caption = 'btnLoadSelf'
    TabOrder = 3
    OnClick = btnLoadSelfClick
  end
  object btnCheckSelfImports: TButton
    Left = 384
    Top = 33
    Width = 113
    Height = 25
    Caption = 'HiJack MsgBox'
    TabOrder = 4
    OnClick = btnCheckSelfImportsClick
  end
  object btnRoolback: TButton
    Left = 272
    Top = 96
    Width = 75
    Height = 25
    Caption = 'Roll back'
    TabOrder = 5
    OnClick = btnRoolbackClick
  end
  object lstExports: TListBox
    Left = 16
    Top = 256
    Width = 241
    Height = 185
    ItemHeight = 13
    TabOrder = 6
  end
  object btnGetFuncAddr: TButton
    Left = 272
    Top = 296
    Width = 97
    Height = 25
    Caption = 'Get Addres'
    TabOrder = 7
    OnClick = btnGetFuncAddrClick
  end
  object edtFuncAddr: TEdit
    Left = 272
    Top = 328
    Width = 97
    Height = 21
    TabOrder = 8
    Text = 'edtFuncAddr'
  end
  object btnCall: TButton
    Left = 272
    Top = 360
    Width = 97
    Height = 25
    Caption = 'Call From Module'
    TabOrder = 9
    OnClick = btnCallClick
  end
  object mmo1: TMemo
    Left = 384
    Top = 248
    Width = 153
    Height = 193
    Lines.Strings = (
      'First need load module '
      'and then Select one routhine'
      'and run it'
      'NOTE: in this sample support '
      'only one signature'
      ''
      'procedure(sender : TObject)'
      ''
      'for sample can use'
      'testdll or  testdllreload.'
      '')
    TabOrder = 10
  end
  object btnBPLLoad: TButton
    Left = 592
    Top = 33
    Width = 113
    Height = 25
    Caption = 'btnBPLLoad'
    TabOrder = 11
    OnClick = btnBPLLoadClick
  end
  object btnTestMemLoadLib: TButton
    Left = 592
    Top = 64
    Width = 129
    Height = 25
    Caption = 'btnTestMemLoadLib'
    TabOrder = 12
    OnClick = btnTestMemLoadLibClick
  end
  object OpenDialog1: TOpenDialog
    Left = 248
  end
end
