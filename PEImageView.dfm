object Form2: TForm2
  Left = 501
  Top = 200
  Width = 565
  Height = 495
  Caption = 'PEImageView'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 16
    Top = 8
    Width = 61
    Height = 13
    Caption = 'Impots Table'
  end
  object TreeView1: TTreeView
    Left = 16
    Top = 32
    Width = 249
    Height = 409
    Indent = 19
    TabOrder = 0
  end
  object Button1: TButton
    Left = 464
    Top = 8
    Width = 75
    Height = 25
    Caption = 'Open'
    TabOrder = 1
    OnClick = Button1Click
  end
  object OpenDialog1: TOpenDialog
    Left = 408
    Top = 8
  end
end
