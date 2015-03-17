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

// Control the way errors are reported by the ML library. Either raise exceptions when ML_ERROR_RAISE is defined , or set the
// LastError code like the original Win APIs. 
// ML_TRAP_EXCEPTION is used with ERROR_RAISE. The exception is raised and trapped immediately, so it stops the debugger, but
// lets the app continue loading 
// Some exceptions are still raised regardless of the error mode. E.g ones in LoadPackage, during allocating memory, hooking APIs, etc
{$DEFINE ML_ERROR_RAISE}
{$IFNDEF _CONSOLE_TESTRUNNER}
{$DEFINE ML_TRAP_EXCEPTION}
{$ENDIF}
