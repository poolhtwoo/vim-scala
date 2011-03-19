" Vim indent file
" Language         : Scala (http://scala-lang.org/)
" Original Author  : Stefan Matthias Aust
" Modifications by : Derek Wyatt
" Last Change: 2011 Mar 10 (Derek Wyatt)

"if exists("b:did_indent")
"  finish
"endif
"let b:did_indent = 1

setlocal indentexpr=GetScalaIndent()
setlocal indentkeys=0{,0},0),!^F,<>>,o,O,e,=case,<CR>
setlocal autoindent

"if exists("*GetScalaIndent")
"    finish
"endif

function! scala#ConditionalConfirm(msg)
  if 0
    call confirm(a:msg)
  endif
endfunction

function! scala#GetLine(lnum)
  let line = substitute(getline(a:lnum), '//.*$', '', '')
  let line = substitute(line, '"[^"]*"', '""', 'g')
  return line
endfunction

function! scala#CountBrackets(line, openBracket, closedBracket)
  let line = substitute(a:line, '"\(.\|\\"\)*"', '', 'g')
  let open = substitute(line, '[^' . a:openBracket . ']', '', 'g')
  let close = substitute(line, '[^' . a:closedBracket . ']', '', 'g')
  return strlen(open) - strlen(close)
endfunction

function! scala#CountParens(line)
  return scala#CountBrackets(a:line, '(', ')')
endfunction

function! scala#CountCurlies(line)
  return scala#CountBrackets(a:line, '{', '}')
endfunction

function! scala#IsParentCase()
  let savedpos = getpos('.')
  call setpos('.', [savedpos[0], savedpos[1], 0, savedpos[3]])
  let [l, c] = searchpos('^\s*\%(\%(\%(abstract\s\+\)\?\%(override\s\+\)\?\<def\>\)\|\%(\<case\>\)\)', 'bnW')
  let retvalue = -1
  if l != 0 && search('\%' . l . 'l\s*\<case\>', 'bnW')
    let retvalue = l
  endif 
  call setpos('.', savedpos)
  return retvalue
endfunction

function! scala#GetLineThatMatchesBracket(openBracket, closedBracket)
  let savedpos = getpos('.')
  let curline = scala#GetLine(line('.'))
  if curline =~ a:closedBracket . '.*' . a:openBracket . '.*' . a:closedBracket
    call setpos('.', [savedpos[0], savedpos[1], 0, savedpos[3]])
    call searchpos(a:closedBracket . '\ze[^' . a:closedBracket . a:openBracket . ']*' . a:openBracket, 'W')
  else
    call setpos('.', [savedpos[0], savedpos[1], 9999, savedpos[3]])
    call searchpos(a:closedBracket, 'Wb')
  endif
  let [lnum, colnum] = searchpairpos(a:openBracket, '', a:closedBracket, 'Wbn')
  call setpos('.', savedpos)
  return lnum
endfunction

function! scala#NumberOfBraceGroups(line)
  let line = substitute(a:line, '[^()]', '', 'g')
  if strlen(line) == 0
    return 0
  endif
  let line = substitute(line, '^)*', '', 'g')
  if strlen(line) == 0
    return 0
  endif
  let line = substitute(line, '^(', '', 'g')
  if strlen(line) == 0
    return 0
  endif
  let c = 1
  let counter = 0
  let groupCount = 0
  while counter < strlen(line)
    let char = strpart(line, counter, 1)
    if char == '('
      let c = c + 1
    elseif char == ')'
      let c = c - 1
    endif
    if c == 0
      let groupCount = groupCount + 1
    endif
    let counter = counter + 1
  endwhile
  return groupCount
endfunction

function! scala#MatchesIncompleteDefValr(line)
  if a:line =~ '^\s*\%(\%(\%(abstract\s\+\)\?\%(override\s\+\)\?\<def\>\)\|\<va[lr]\>\).*[=({]\s*$'
    return 1
  else
    return 0
  endif
endfunction

function! scala#LineIsCompleteIf(line)
  if scala#CountBrackets(a:line, '{', '}') == 0 &&
   \ scala#CountBrackets(a:line, '(', ')') == 0 &&
   \ a:line =~ '^\s*\<if\>\s*([^)]*)\s*\S.*$'
    return 1
  else
    return 0
  endif
endfunction

function! scala#LineCompletesIfElse(lnum, line)
  if a:line =~ '^\s*\%(\<if\>\|\%(}\s*\)\?\<else\>\)'
    return 0
  endif
  let result = search('^\%(\s*\<if\>\s*(.*).*\n\|\s*\<if\>\s*(.*)\s*\n.*\n\)\%(\s*\<else\>\s*\<if\>\s*(.*)\s*\n.*\n\)*\%(\s*\<else\>\s*\n\|\s*\<else\>[^{]*\n\)\?\%' . a:lnum . 'l', 'Wbn')
  if result != 0 && scala#GetLine(prevnonblank(a:lnum - 1)) !~ '{\s*$'
    return result
  endif
  return 0
endfunction

function! scala#LineCompletesDefValr(lnum, line)
  let bracketCount = scala#CountBrackets(a:line, '{', '}')
  if bracketCount < 0
    let matchedBracket = scala#GetLineThatMatchesBracket('{', '}')
    if ! scala#MatchesIncompleteDefValr(scala#GetLine(matchedBracket))
      let possibleDefValr = scala#GetLine(prevnonblank(matchedBracket - 1))
      if matchedBracket != -1 && scala#MatchesIncompleteDefValr(possibleDefValr)
        return 1
      else
        return 0
      endif
    else
      return 0
    endif
  elseif bracketCount == 0
    let bracketCount = scala#CountBrackets(a:line, '(', ')')
    if bracketCount < 0
      let matchedBracket = scala#GetLineThatMatchesBracket('(', ')')
      if ! scala#MatchesIncompleteDefValr(scala#GetLine(matchedBracket))
        let possibleDefValr = scala#GetLine(prevnonblank(matchedBracket - 1))
        if matchedBracket != -1 && scala#MatchesIncompleteDefValr(possibleDefValr)
          return 1
        else
          return 0
        endif
      else
        return 0
      endif
    elseif bracketCount == 0
      let possibleDefValr = scala#GetLine(prevnonblank(a:lnum - 1))
      if scala#MatchesIncompleteDefValr(possibleDefValr) && possibleDefValr =~ '^.*=\s*$'
        return 1
      else
        let possibleIfElse = scala#LineCompletesIfElse(a:lnum, a:line)
        if possibleIfElse != 0
          let possibleDefValr = scala#GetLine(prevnonblank(possibleIfElse - 1))
          if scala#MatchesIncompleteDefValr(possibleDefValr) && possibleDefValr =~ '^.*=\s*$'
            return 2
          else
            return 0
          endif
        else
          return 0
        endif
      endif
    else
      return 0
    endif
  endif
endfunction

function! scala#SpecificLineCompletesBrackets(lnum, openBracket, closedBracket)
  let savedpos = getpos('.')
  call setpos('.', [savedpos[0], a:lnum, 9999, savedpos[3]])
  let retv = scala#LineCompletesBrackets(a:openBracket, a:closedBracket)
  call setpos('.', savedpos)

  return retv
endfunction

function! scala#LineCompletesBrackets(openBracket, closedBracket)
  let savedpos = getpos('.')
  let offline = 0
  while offline == 0
    let [lnum, colnum] = searchpos(a:closedBracket, 'Wb')
    let [lnumA, colnumA] = searchpairpos(a:openBracket, '', a:closedBracket, 'Wbn')
    if lnum != lnumA
      let [lnumB, colnumB] = searchpairpos(a:openBracket, '', a:closedBracket, 'Wbnr')
      let offline = 1
    endif
  endwhile
  call setpos('.', savedpos)
  if lnumA == lnumB && colnumA == colnumB
    return lnumA
  else
    return -1
  endif
endfunction

function! GetScalaIndent()
  " Find a non-blank line above the current line.
  let prevlnum = prevnonblank(v:lnum - 1)

  " Hit the start of the file, use zero indent.
  if prevlnum == 0
    return 0
  endif

  let ind = indent(prevlnum)
  let originalIndentValue = ind
  let prevline = scala#GetLine(prevlnum)
  let curlnum = v:lnum
  let curline = scala#GetLine(curlnum)

  if prevline =~ '^\s*/\*\*'
    return ind + 1
  endif

  if curline =~ '^\s*\*'
    return cindent(curlnum)
  endif

  " If this line starts with a { then make it indent the same as the previous line
  if curline =~ '^\s*{'
    call scala#ConditionalConfirm("1")
    " Unless, of course, the previous one is a { as well
    if prevline !~ '^\s*{'
      call scala#ConditionalConfirm("2")
      return indent(prevlnum)
    endif
  endif

  " Indent html literals
  if prevline !~ '/>\s*$' && prevline =~ '^\s*<[a-zA-Z][^>]*>\s*$'
    call scala#ConditionalConfirm("3")
    return ind + &shiftwidth
  endif

  " Add a 'shiftwidth' after lines that start a block
  " If 'if', 'for' or 'while' end with ), this is a one-line block
  " If 'val', 'var', 'def' end with =, this is a one-line block
  if (prevline =~ '^\s*\<\%(\%(}\?\s*else\s\+\)\?if\|for\|while\)\>.*[)=]\s*$' && scala#NumberOfBraceGroups(prevline) <= 1)
        \ || prevline =~ '^\s*\%(abstract\s\+\)\?\%(override\s\+\)\?\<def\>.*=\s*$'
        \ || prevline =~ '^\s*\<va[lr]\>.*[=]\s*$'
        \ || prevline =~ '^\s*\%(}\s*\)\?\<else\>\s*$'
        \ || prevline =~ '=\s*$'
    call scala#ConditionalConfirm("4")
    let ind = ind + &shiftwidth
  endif

  let bracketCount = scala#CountBrackets(prevline, '(', ')')
  if bracketCount > 0 || prevline =~ '.*(\s*$'
    call scala#ConditionalConfirm("5a")
    let ind = ind + &shiftwidth
    break
  elseif bracketCount < 0
    call scala#ConditionalConfirm("6a")
    " if the closing brace actually completes the braces entirely, then we
    " have to indent to line that started the whole thing
    let completeLine = scala#LineCompletesBrackets('(', ')')
    if completeLine != -1
      call scala#ConditionalConfirm("8a")
      let prevCompleteLine = scala#GetLine(prevnonblank(completeLine - 1))
      " However, what actually started this part looks like it was a function
      " definition, so we need to indent to that line instead.  This is 
      " actually pretty weak at the moment.
      if prevCompleteLine =~ '=\s*$'
        call scala#ConditionalConfirm("9a")
        let ind = indent(prevnonblank(completeLine - 1))
      else
        call scala#ConditionalConfirm("10a")
        let ind = indent(completeLine)
      endif
    else
      " This is the only part that's different from from the '{', '}' one below
      " Yup... some refactoring is necessary at some point.
      let ind = ind + (bracketCount * &shiftwidth)
    endif
    break
  endif

  let lineCompletedBrackets = 0
  if ind == originalIndentValue
    let bracketCount = scala#CountBrackets(prevline, '{', '}')
    if bracketCount > 0 || prevline =~ '.*{\s*$'
      call scala#ConditionalConfirm("5b")
      let ind = ind + &shiftwidth
      break
    elseif bracketCount < 0
      call scala#ConditionalConfirm("6b")
      " if the closing brace actually completes the braces entirely, then we
      " have to indent to line that started the whole thing
      let completeLine = scala#LineCompletesBrackets('{', '}')
      if completeLine != -1
        call scala#ConditionalConfirm("8b")
        let prevCompleteLine = scala#GetLine(prevnonblank(completeLine - 1))
        " However, what actually started this part looks like it was a function
        " definition, so we need to indent to that line instead.  This is 
        " actually pretty weak at the moment.
        if prevCompleteLine =~ '=\s*$'
          call scala#ConditionalConfirm("9b")
          let ind = indent(prevnonblank(completeLine - 1))
        else
          call scala#ConditionalConfirm("10b")
          let ind = indent(completeLine)
        endif
      else
        let lineCompletedBrackets = 1
      endif
      break
    endif
  endif

  if curline =~ '^\s*}\?\s*\<else\>\%(\s\+\<if\>\s*(.*)\)\?\s*{\?\s*$' &&
   \ ! scala#LineIsCompleteIf(prevline) &&
   \ prevline !~ '^.*}\s*$'
    let ind = ind - &shiftwidth
  endif

  " Subtract a 'shiftwidth' on '}' or html
  let curCurlyCount = scala#CountCurlies(curline)
  if curCurlyCount < 0
    call scala#ConditionalConfirm("14a")
    let matchline = scala#GetLineThatMatchesBracket('{', '}')
    return indent(matchline)
  elseif curline =~ '^\s*</[a-zA-Z][^>]*>'
    call scala#ConditionalConfirm("14c")
    let ind = ind - &shiftwidth
  endif

  let prevParenCount = scala#CountParens(prevline)
  if prevline =~ '^\s*\<for\>.*$' && prevParenCount > 0
    call scala#ConditionalConfirm("15")
    let ind = indent(prevlnum) + 5
  endif

  let prevCurlyCount = scala#CountCurlies(prevline)
  if prevCurlyCount == 0 && prevline =~ '^.*=>\s*$' && curline !~ '^\s*\<case\>'
    call scala#ConditionalConfirm("16")
    let ind = ind + &shiftwidth
  endif

  if ind == originalIndentValue && curline =~ '^\s*\<case\>'
    call scala#ConditionalConfirm("17")
    let parentCase = scala#IsParentCase()
    if parentCase != -1
      call scala#ConditionalConfirm("17a")
      let ind = indent(parentCase)
    endif
  endif

  if prevline =~ '^\s*\*/'
    call scala#ConditionalConfirm("18")
    let ind = ind - 1
  endif

  if ind == originalIndentValue
    let indentMultiplier = scala#LineCompletesDefValr(prevlnum, prevline)
    if indentMultiplier != 0
      call scala#ConditionalConfirm("19a")
      let ind = ind - (indentMultiplier * &shiftwidth)
    elseif lineCompletedBrackets == 0
      call scala#ConditionalConfirm("19b")
      if scala#GetLine(prevnonblank(prevlnum - 1)) =~ '^.*\<else\>\s*\%(//.*\)\?$'
        call scala#ConditionalConfirm("19c")
        let ind = ind - &shiftwidth
      elseif scala#LineCompletesIfElse(prevlnum, prevline)
        call scala#ConditionalConfirm("19d")
        let ind = ind - &shiftwidth
      elseif scala#CountParens(curline) < 0 && scala#GetLine(scala#GetLineThatMatchesBracket('(', ')')) =~ '.*(\s*$'
        " Handles situations that look like this:
        " 
        "   val a = func(
        "     10
        "   )
        "
        " or
        "
        "   val a = func(
        "     10
        "   ).somethingHere()
        call scala#ConditionalConfirm("19e")
        let ind = ind - &shiftwidth
      endif
    endif
  endif

  call scala#ConditionalConfirm("returning " . ind)

  return ind
endfunction
" vim:set ts=2 sts=2 sw=2:
" vim600:fdm=marker fdl=1 fdc=0:
