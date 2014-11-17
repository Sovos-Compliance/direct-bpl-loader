{*******************************************************************************
*  Created by Vladimir Georgiev, 2014                                          *
*                                                                              *
*  Description:                                                                *
*  Common defines(s) used in the units of the Memory Load library              *
*                                                                              *
*******************************************************************************}

// Set MLHOOKED to use the Hooked mode of the API, or undefine it to use the
// Unhooked mode with the distinctly named functions
// The _CONSOLE_TESTRUNNER is checked to see if tests are being run. For ease of use the test apps define the MLHOOKED manually
{$IFNDEF _CONSOLE_TESTRUNNER}
{$DEFINE MLHOOKED}
{$ENDIF}