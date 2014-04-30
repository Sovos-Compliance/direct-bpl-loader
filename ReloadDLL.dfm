object Form1: TForm1
  Left = 305
  Top = 208
  Width = 605
  Height = 384
  Caption = 'Form1'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Button1: TButton
    Left = 32
    Top = 16
    Width = 75
    Height = 25
    Caption = 'Load Start'
    TabOrder = 0
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 32
    Top = 56
    Width = 75
    Height = 25
    Caption = 'Load Stop'
    TabOrder = 1
    OnClick = Button2Click
  end
  object Button3: TButton
    Left = 264
    Top = 16
    Width = 121
    Height = 25
    Caption = 'Reload Function'
    TabOrder = 2
    OnClick = Button3Click
  end
end
