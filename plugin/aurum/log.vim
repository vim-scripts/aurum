"▶1
scriptencoding utf-8
if !exists('s:_pluginloaded')
    execute frawor#Setup('0.2', {'@/table': '0.1',
                \        '@aurum/cmdutils': '0.0',
                \         '@aurum/bufvars': '0.0',
                \            '@aurum/edit': '1.1',
                \                  '@/fwc': '0.3',
                \            '@aurum/repo': '2.2',
                \             '@/commands': '0.0',
                \            '@/functions': '0.0',
                \              '@/options': '0.0',}, 0)
    call FraworLoad('@/commands')
    call FraworLoad('@/functions')
    let s:logcomp=[]
    let s:logfunc={}
    call s:_f.command.add('AuLog', s:logfunc, {'nargs': '*',
                \                           'complete': s:logcomp})
    finish
elseif s:_pluginloaded
    finish
endif
let s:F.glog={}
let s:F.graph={}
let s:F.temp={}
let s:_options={
            \'ignorefiles': {'default': [],
            \                'checker': 'list in [patch renames copies files]'},
            \'closewindow': {'default': 1, 'filter': 'bool'},
            \'procinput':   {'default': 1, 'checker': 'range 0 2'},
        \}
let s:_messages={
            \'2multl': 'Two multiline statements on one line',
            \'argmis': 'Missing argument #%u for keyword %s',
            \  'ebuf': 'Switched to another buffer: exiting',
        \}
" iterfuncs :: {fname: { "start": startfunc, "next": nextfunc }}
" startfunc (always) :: repo, opts, * → d
let s:iterfuncs={}
"▶1 graph
"▶2 graph.update_state :: graph, gstate → + graph
function s:F.graph.update_state(s)
    let self.prev_state=self.state
    let self.state=a:s
endfunction
"▶2 graph.ensure_capacity :: graph, num_columns → + graph
function s:F.graph.ensure_capacity(num_columns)
    let mdiff=(a:num_columns*2)-len(self.mapping)
    if mdiff>0
        let plist=repeat([-1], mdiff)
        let self.mapping+=plist
        let self.new_mapping+=plist
    endif
endfunction
"▶2 graph.insert_into_new_columns :: graph, hex, mapindex → mapindex + graph
function s:F.graph.insert_into_new_columns(hex, mapindex)
    let i=0
    for hex in self.new_columns
        if hex is# a:hex
            let self.mapping[a:mapindex]=i
            return a:mapindex+2
        endif
        let i+=1
    endfor
    let self.mapping[a:mapindex]=len(self.new_columns)
    call add(self.new_columns, a:hex)
    return a:mapindex+2
endfunction
"▶2 graph.update_columns :: graph → + graph
function s:F.graph.update_columns()
    let self.columns=self.new_columns
    let self.new_columns=[]
    let max_new_columns=len(self.columns)+self.num_parents
    call self.ensure_capacity(max_new_columns)
    let self.mapping_size=2*max_new_columns
    if !empty(self.mapping)
        call remove(self.mapping, 0, self.mapping_size-1)
    endif
    call extend(self.mapping, repeat([-1], self.mapping_size), 0)
    let seen=0
    let midx=0
    let is_cs_in_columns=1
    let num_columns=len(self.columns)
    for i in range(num_columns+1)
        if i==num_columns
            if seen
                break
            endif
            let is_cs_in_columns=0
            let ccshex=self.cs.hex
        else
            let ccshex=self.columns[i]
        endif
        if ccshex is# self.cs.hex
            let oldmidx=midx
            let seen=1
            let self.commit_index=i
            for parent in self.interesting_parents
                let midx=self.insert_into_new_columns(parent, midx)
            endfor
            if midx==oldmidx
                let midx+=2
            endif
        else
            let midx=self.insert_into_new_columns(ccshex, midx)
        endif
    endfor
    while self.mapping_size>1 && self.mapping[self.mapping_size-1]==-1
        let self.mapping_size-=1
    endwhile
    let self.width=(len(self.columns)+self.num_parents+(self.num_parents<1)
                \  -(is_cs_in_columns))*2
endfunction
"▶2 graph.update :: graph, cs → + graph
function s:F.graph.update(cs)
    let self.cs=a:cs
    let self.interesting_parents=copy(a:cs.parents)
    let self.num_parents=len(self.interesting_parents)
    let self.prev_commit_index=self.commit_index
    call self.update_columns()
    let self.expansion_row=0
    if self.state isnot# 'padding'
        let self.state='skip'
    elseif self.num_parents>2 &&
                \self.commit_index<(len(self.columns)-1)
        let self.state='precommit'
    else
        let self.state='commit'
    endif
endfunction
"▶2 graph.is_mapping_correct :: graph → Bool
function s:F.graph.is_mapping_correct()
    return empty(filter(self.mapping[:(self.mapping_size-1)],
                \       '!(v:val==-1 || v:val==v:key/2)'))
endfunction
"▶2 graph.pad_horizontally :: graph, chars_written → String
" XXX Replace somehow?
function s:F.graph.pad_horizontally(chars_written)
    if a:chars_written>=self.width
        return ''
    endif
    return repeat(' ', self.width-a:chars_written)
endfunction
"▶2 graph.output_padding_line :: graph → String
function s:F.graph.output_padding_line()
    let lnc=len(self.new_columns)
    return repeat('| ', lnc).self.pad_horizontally(lnc*2)
endfunction
"▶2 graph.output_skip_line :: graph → String
function s:F.graph.output_skip_line()
    call self.update_state(((self.num_parents>2 &&
                \            self.commit_index<(len(self.columns)-1))?
                \               ('precommit'):
                \               ('commit')))
    return '...'.self.pad_horizontally(3)
endfunction
"▶2 graph.output_pre_commit_line :: graph → String
function s:F.graph.output_pre_commit_line()
    let num_expansion_rows=(self.num_parents-2)*2
    let seen=0
    let r=''
    let i=-1
    for hex in self.columns
        let i+=1
        if hex is# self.cs.hex
            let seen=1
            let r.='|'.repeat(' ', self.expansion_row)
        elseif seen && self.expansion_row==0
            let r.='|\'[self.prev_state is# 'postmerge' &&
                        \self.prev_commit_index<i]
        elseif seen && self.expansion_row>0
            let r.='\'
        else
            let r.='|'
        endif
        let r.=' '
    endfor
    let r.=self.pad_horizontally(len(r))
    let self.expansion_row+=1
    if self.expansion_row>num_expansion_rows
        call self.update_state('commit')
    endif
    return r
endfunction
"▶2 graph.output_commit_char :: graph → String
function s:F.graph.output_commit_char()
    if has_key(self.skipchangesets, self.cs.hex)
        return '*'
    endif
    return '@o'[index(self.workcss, self.cs.hex)==-1]
endfunction
"▶2 graph.draw_octopus_merge :: graph → String
function s:F.graph.draw_octopus_merge()
    let r=''
    for i in range(((self.num_parents-2)*2)-1)
        let r.='-'
    endfor
    let r.='.'
    return r
endfunction
"▶2 graph.output_commit_line :: graph → String
function s:F.graph.output_commit_line()
    let seen=0
    let r=''
    let lcolumns=len(self.columns)
    for i in range(lcolumns+1)
        if i==lcolumns
            if seen
                break
            endif
            let ccshex=self.cs.hex
        else
            let ccshex=self.columns[i]
        endif
        if ccshex is# self.cs.hex
            let seen=1
            let r.=self.output_commit_char()
            if self.num_parents>2
                let r.=self.draw_octopus_merge()
            endif
        elseif seen && self.num_parents>2
            let r.='\'
        elseif seen && self.num_parents==2
            let r.='|\'[self.prev_state is# 'postmerge' &&
                        \self.prev_commit_index<i]
        else
            let r.='|'
        endif
        let r.=' '
    endfor
    let r.=self.pad_horizontally(len(r))
    call self.update_state(((self.num_parents>1)?
                \             ('postmerge'):
                \          ((self.is_mapping_correct())?
                \             ('padding')
                \          :
                \             ('collapsing'))))
    return r
endfunction
"▶2 graph.output_post_merge_line :: graph → String
function s:F.graph.output_post_merge_line()
    let seen=0
    let r=''
    let lcolumns=len(self.columns)
    for i in range(lcolumns+1)
        if i==lcolumns
            if seen
                break
            endif
            let ccshex=self.cs.hex
        else
            let ccshex=self.columns[i]
        endif
        if ccshex is# self.cs.hex
            let seen=1
            let r.='|'.repeat('\ ', self.num_parents-1)
        else
            let r.='|\'[seen].' '
        endif
    endfor
    let r.=self.pad_horizontally(len(r))
    call self.update_state(((self.is_mapping_correct())?
                \               ('padding'):
                \               ('collapsing')))
    return r
endfunction
"▶2 graph.output_collapsing_line :: graph → String
function s:F.graph.output_collapsing_line()
    let used_horizontal=0
    let horizontal_edge=-1
    let horizontal_edge_target=-1
    let self.new_mapping=repeat([-1], self.mapping_size)
    for [i, target] in map(self.mapping[:(self.mapping_size-1)],
                \          '[v:key, v:val]')
        if target==-1
            continue
        elseif i==target*2
            let self.new_mapping[i]=target
        elseif self.new_mapping[i-1]==-1
            let self.new_mapping[i-1]=target
            if horizontal_edge==-1
                let horizontal_edge=i
                let horizontal_edge_target=target
                let j=(target*2)+3
                while j<i-2
                    let self.new_mapping[j]=target
                    let j+=2
                endwhile
            endif
        elseif self.new_mapping[i-1]==target
        else
            let self.new_mapping[i-2]=target
            if horizontal_edge==-1
                let horizontal_edge=1
            endif
        endif
    endfor
    if self.mapping[self.mapping_size-1]==-1
        let self.mapping_size-=1
    endif
    let r=''
    for [i, target] in map(self.new_mapping[:(self.mapping_size-1)],
                \          '[v:key, v:val]')
        if target==-1
            let r.=' '
        elseif target*2==i
            let r.='|'
        elseif target==horizontal_edge_target && i!=horizontal_edge-1
            if i!=(target*2)+3
                let self.new_mapping[i]=-1
            endif
            let used_horizontal=1
            let r.='_'
        else
            if used_horizontal && i<horizontal_edge
                let self.new_mapping[i]=-1
            endif
            let r.='/'
        endif
    endfor
    let r.=self.pad_horizontally(len(r))
    let [self.mapping, self.new_mapping]=
                \[self.new_mapping, self.mapping]
    if self.is_mapping_correct()
        call self.update_state('padding')
    endif
    return r
endfunction
"▶2 graph.next_line :: graph → String
let s:gstatesfmap={
            \'padding':    s:F.graph.output_padding_line,
            \'skip':       s:F.graph.output_skip_line,
            \'precommit':  s:F.graph.output_pre_commit_line,
            \'commit':     s:F.graph.output_commit_line,
            \'postmerge':  s:F.graph.output_post_merge_line,
            \'collapsing': s:F.graph.output_collapsing_line,
        \}
function s:F.graph.next_line()
    return call(s:gstatesfmap[self.state], [], self)
endfunction
"▶2 graph.padding_line :: graph → String
function s:F.graph.padding_line()
    if self.state isnot# 'commit'
        return self.next_line()
    endif
    if self.num_parents<3
        let r.=repeat('| ', len(self.columns))
    else
        let r.=join(map(copy(self.columns),
                    \   '"|".((v:val is# "'.self.cs.hex.'")?'.
                    \           'repeat(" ", (self.num_parents-2)*2):'.
                    \           '" ")'), '')
    endif
    let r.=self.pad_horizontally(len(r))
    let self.prev_state='padding'
    return r
endfunction
"▶2 graph.show_commit :: graph → [String]
function s:F.graph.show_commit()
    let r=[]
    while 1
        try
            if self.state is# 'commit'
                break
            endif
        finally
            " XXX We need at least one iteration. :finally makes sure it will be 
            " done
            let r+=[self.next_line()]
        endtry
    endwhile
    return r
endfunction
"▶2 graph.show_remainder :: graph → [String]
function s:F.graph.show_remainder()
    let r=[]
    while self.state isnot# 'padding'
        let r+=[self.next_line()]
    endwhile
    return r
endfunction
"▶1 glog
"▶2 glog.utfedges
function s:F.glog.utfedges(seen, hex, parents)
    let nodeidx=index(a:seen, a:hex)
    if nodeidx==-1
        let nodeidx=len(a:seen)
        call add(a:seen, a:hex)
    endif
    let knownparents=[]
    let newparents=[]
    for parenthex in a:parents
        call add(((index(a:seen, parenthex)==-1)?
                    \   (newparents):
                    \   (knownparents)),
                    \parenthex)
    endfor
    let ncols=len(a:seen)
    call remove(a:seen, nodeidx)
    call extend(a:seen, newparents, nodeidx)
    let edges=map(knownparents, '['.nodeidx.', index(a:seen, v:val)]')
    if !empty(newparents)
        call add(edges, [nodeidx, nodeidx])
        if len(newparents)>1
            call add(edges, [nodeidx, nodeidx+1])
        endif
    endif
    let nmorecols=len(a:seen)-ncols
    return [nodeidx, edges, ncols, nmorecols]
endfunction
"▶2 glog.fix_long_right_edges
function s:F.glog.fix_long_right_edges(edges)
    call map(a:edges, '((v:val[1]>v:val[0])?([v:val[0], v:val[1]+1]):(v:val))')
endfunction
"▶2 glog.get_nodeline_edges_tail
function s:F.glog.get_nodeline_edges_tail(node_index, p_node_index, n_columns,
            \                             n_columns_diff, p_diff, fix_tail)
    if a:fix_tail && a:n_columns_diff==a:p_diff && a:n_columns_diff!=0
        if a:n_columns_diff==-1
            let start=max([a:node_index+1, a:p_node_index])
            return repeat(['|', ' '], (start-a:node_index-1))+
                        \repeat(['/', ' '], (a:n_columns-start))
        else
            return repeat(['\', ' '], (a:n_columns-a:node_index-1))
        endif
    else
        return repeat(['|', ' '], (a:n_columns-a:node_index-1))
    endif
endfunction
"▶2 glog.draw_edges
function s:F.glog.draw_edges(edges, nodeline, interline)
    for [start, end] in a:edges
        if start==end+1
            let a:interline[2*end   + 1]='/'
        elseif start==end-1
            let a:interline[2*start + 1]='\'
        elseif start==end
            let a:interline[2*start    ]='|'
        else
            let a:nodeline[2*end]='+'
            if start>end
                let [start, end]=[end, start]
            endif
            for i in range(2*start+1, 2*end-1)
                if a:nodeline[i] isnot# '+'
                    let a:nodeline[i]='-'
                endif
            endfor
        endif
    endfor
endfunction
"▶2 glog.get_padding_line
function s:F.glog.get_padding_line(ni, n_columns, edges)
    let c=' '
    if index(a:edges, [a:ni, a:ni-1])!=-1 || index(a:edges, [a:ni, a:ni])!=-1
        let c='|'
    endif
    return repeat(['|', ' '], a:ni)+
                \[c, ' ']+
                \repeat(['|', " "], (a:n_columns-a:ni-1))
endfunction
"▶2 glog.addlines
function s:F.glog.addlines(special, lnum)
    let mapexpr='[v:val[0]+'.a:lnum.']+v:val[1:]'
    call map(a:special, 'v:key[-2:] is? "_r"?'.
                \             'map(v:val, '.string(mapexpr).'):'.
                \             mapexpr)
    return a:special
endfunction
"▶2 glog.addcols
function s:F.glog.addcols(special, cnum)
    let mapexpr='[v:val[0], v:val[1]+'.a:cnum.']+v:val[2:]'
    call map(a:special, 'v:key[-2:] is? "_r"?'.
                \             'map(v:val, '.string(mapexpr).'):'.
                \             mapexpr)
    return a:special
endfunction
"▶2 glog.utf
function s:F.glog.utf(state, type, char, text, coldata)
    let [idx, edges, ncols, coldiff]=a:coldata
    let add_padding_line=0
    let lnum = (has_key(a:text, 'text') ? len(a:text.text) : 0)
    if coldiff==-1
        call s:F.glog.fix_long_right_edges(edges)
        if lnum>2
            let add_padding_line=!empty(map(filter(copy(edges),
                        \                          '(v:val[0]+1)<v:val[1]'),
                        \                   'v:val[0]'))
        endif
    endif
    let fix_nodeline_tail = (lnum<=2 && add_padding_line)
    let shift_interline=repeat(['|', ' '], idx)
    let nodeline=copy(shift_interline)+
                \[a:char, ' ']+
                \s:F.glog.get_nodeline_edges_tail(idx,     a:state[1], ncols,
                \                                 coldiff, a:state[0],
                \                                 fix_nodeline_tail)
    if coldiff==-1
        let n_spaces=1
        let edge_ch='/'
    elseif coldiff==0
        let n_spaces=2
        let edge_ch='|'
    else
        let n_spaces=3
        let edge_ch='\'
    endif
    let shift_interline+=repeat([' '], n_spaces)+
                \        repeat([edge_ch, ' '], (ncols-idx-1))
    call s:F.glog.draw_edges(edges, nodeline, shift_interline)
    let lines=[nodeline]
    if add_padding_line
        call add(lines, s:F.glog.get_padding_line(idx, ncols, edges))
    endif
    if has_key(a:text, 'skip')
        let joined_sil=join(shift_interline, '')
        let joined_nl=join(nodeline, '')
        let a:text.text=[]
        if joined_nl!~#'\v^[*| ]+$'
            let a:text.text+=[joined_nl]
        endif
        if joined_sil!~#'\v^[| ]+$' &&
                    \joined_sil isnot# tr(joined_nl, a:char, '|')
            let a:text.text+=[joined_sil]
        endif
        return a:text
    else
        call add(lines, shift_interline)
    endif
    let ltdiff=lnum-len(lines)
    if ltdiff>0
        let extra_interline=repeat(['|', ' '], ncols+coldiff)
        call extend(lines, repeat([extra_interline], ltdiff))
    else
        call extend(a:text.text, repeat([''], -ltdiff))
    endif
    let indentation_level=2*max([ncols, ncols+coldiff])
    let a:state[0]=coldiff
    let a:state[1]=idx
    call map(lines, 'printf("%-*s ", indentation_level, join(v:val, ""))')
    let curspecial=a:text.special
    let shiftlen=len(lines[0])
    call s:F.glog.addcols(a:text.special, shiftlen)
    let a:text.block_r=[[0, shiftlen],
                \       [len(a:text.text)-1,
                \        max(map(copy(lines), 'len(v:val)'))]]
    let curspecial.bullet=[0, stridx(lines[0], a:char), a:char]
    call map(a:text.text, 'lines[v:key].v:val')
    return a:text
endfunction
"▶2 glog.graph_init :: repo, [cs] → graph
let s:defgraph={
            \'cs':                0,
            \'num_parents':       0,
            \'expansion_row':     0,
            \'state':             'padding',
            \'prev_state':        'padding',
            \'commit_index':      0,
            \'prev_commit_index': 0,
            \'columns':           [],
            \'new_columns':       [],
            \'mapping':           [],
            \'new_mapping':       [],
            \'mapping_size':      0,
            \'skipchangesets':    {},
        \}
function s:F.glog.graph_init(showparents, opts, repo)
    let graph=deepcopy(s:defgraph)
    let graph.repo=a:repo
    let graph.workcss=a:showparents
    let graph.skipchangesets=a:opts.skipchangesets
    call extend(graph, s:F.graph)
    return graph
endfunction
"▶2 glog.show_log :: graph, cs, Text → Text
function s:F.glog.show_log(graph, cs, text)
    let lines=((a:graph.cs is 0)?([]):(a:graph.show_remainder()))
    call a:graph.update(a:cs)
    let lines+=a:graph.show_commit()
    let skip=has_key(a:text, 'skip')
    if skip && len(lines)==1 && lines[0]!~#'[^|* ]'
        return a:text
    endif
    let collen=len(lines[-1])
    let a:text.block_r[0][1]+=collen
    let a:text.block_r[1][1]+=collen
    call s:F.glog.addcols(a:text.special, collen)
    let lines[-1]=lines[-1][:-2].' '.get(a:text.text, 0, '')
    let cchar=a:graph.output_commit_char()
    let bidx=stridx(lines[-1], cchar)
    if bidx!=-1
        let a:text.special.bullet=[0, bidx, cchar]
    endif
    for line in a:text.text[1:]
        let lines+=[a:graph.next_line()[:-2].' '.line]
    endfor
    let a:text.text=lines
    return a:text
endfunction
"▶2 s:DateCmp :: cs, cs → -1|0|1
function s:DateCmp(a, b)
    let a=a:a.time
    let b=a:b.time
    return ((a==b)?(0):((a>b)?(-1):(1)))
endfunction
let s:_functions+=['s:DateCmp']
"▶2 glog.graphlog
function s:F.glog.graphlog(repo, opts, csiterfuncs, bvar, read)
    "▶3 Get grapher
    if get(a:repo, 'has_octopus_merges', 1)
        let literfuncs=s:iterfuncs.git
    else
        let literfuncs=s:iterfuncs.hg
    endif
    "▶3 Initialize variables
    let haslimit=(has_key(a:opts, 'limit') && a:opts.limit)
    if haslimit
        let limit=a:opts.limit
    endif
    let foundfirst=0
    let csbuf=[]
    let reqprops=keys(a:opts.reqs)
    call filter(reqprops, 'index(a:repo.initprops, v:val)==-1')
    let a:opts.skipchangesets={}
    let skipchangesets=a:opts.skipchangesets
    let firstcs=1
    let lastline=0
    let r=[]
    "▶3 Initialize variables not required for reading
    if !a:read
        let specials={}
        let rectangles=[]
        let csstarts={}
        let a:bvar.rectangles=rectangles
        let a:bvar.specials=specials
        let a:bvar.csstarts=csstarts
        let didredraw=0
        let procinput=a:bvar.procinput
        let lastw0line=-1
        let buf=bufnr('%')
    endif
    "▶3 Initialize iterator functions
    let ld=literfuncs.start(a:repo,a:opts,[a:repo.functions.getworkhex(a:repo)])
    let csd=a:csiterfuncs.start(a:repo, a:opts)
    let checkd=s:iterfuncs.check.start(a:repo, a:opts)
    "▲3
    while 1 && (!haslimit || limit)
        let cs=a:csiterfuncs.next(csd)
        if cs is 0 "▶3
            return r
        endif "▲3
        let skip=!s:iterfuncs.check.check(checkd, cs)
        "▶3 Add cs to skipchangesets or get its properties
        if skip
            let a:opts.skipchangesets[cs.hex]=cs
        else
            call map(copy(reqprops),
                        \'a:repo.functions.getcsprop(a:repo, cs, v:val)')
            let foundfirst=1
            if haslimit
                let limit-=1
            endif
        endif
        "▲3
        if foundfirst
            let csbuf+=[cs]
            if !skip
                for cs in csbuf
                    let [lines, rectangle, special]=literfuncs.proccs(ld, cs)
                    "▶3 Add various information to bvar
                    if !a:read && rectangle isnot 0
                        let rectangle[0][0]=lastline
                        let lastline+=len(lines)
                        let rectangle[1][0]=lastline-1
                        let rectangle+=[cs.hex]
                        call add(rectangles, rectangle)
                        let csstarts[cs.hex]=rectangle[0][0]
                        if special isnot 0
                            let specials[cs.hex]=special
                        endif
                    endif
                    "▶3 Add lines to returned list if reading
                    if a:read
                        let r+=lines
                    "▶3 Add lines to buffer if not, process user input
                    else
                        "▶4 Add lines to buffer
                        if firstcs
                            call setline(1, lines)
                            let firstcs=0
                        else
                            call append('$', lines)
                        endif
                        "▶4 Process user input
                        if didredraw
                            if procinput && getchar(1)
                                let input=''
                                while getchar(1)
                                    let char=getchar()
                                    if type(char)==type(0)
                                        let input.=nr2char(char)
                                    else
                                        let input.=char
                                    endif
                                endwhile
                                execute 'normal' input
                                if bufnr('%')!=buf
                                    if bufexists(buf)
                                        execute 'silent bwipeout!' buf
                                    endif
                                    call s:_f.warn('ebuf')
                                    return []
                                endif
                                let lw0=line('w0')
                                if lw0!=lastw0line
                                    redraw
                                    let didredraw=(line('$')>=lw0+winheight(0))
                                    let lastw0line=lw0
                                endif
                            endif
                        "▶4 Redraw if necessary
                        elseif line('$')>=line('w0')+winheight(0)
                            redraw
                            let didredraw=1
                            let lastw0line=line('w0')
                        endif
                        "▲4
                    endif
                    "▲3
                    unlet rectangle special
                endfor
                call remove(csbuf, 0, -1)
            endif
        endif
        unlet cs
    endwhile
    return r
endfunction
"▶1 iterfuncs: loggers
"▶2 iterfuncs.git
" TODO Fix skipping changesets if possible
let s:iterfuncs.git={}
function s:iterfuncs.git.start(repo, opts, ...)
    let graph=s:F.glog.graph_init(get(a:000, 0, []), a:opts, a:repo)
    return {'graph': graph, 'opts': a:opts, 'repo': a:repo}
endfunction
function s:iterfuncs.git.proccs(d, cs)
    if has_key(a:d.opts.skipchangesets, a:cs.hex)
        let text={'skip': 1, 'text': [], 'special': {}}
    else
        let text=a:d.opts.templatefunc(a:cs, a:d.opts, a:d.repo)
    endif
    let text.block_r=[[0, 0],
                \     [len(text.text)-1,
                \      max(map(copy(text.text), 'len(v:val)'))]]
    let text=s:F.glog.show_log(a:d.graph, a:cs, text)
    return [text.text, text.block_r, text.special]
endfunction
"▶2 iterfuncs.hg
let s:iterfuncs.hg={}
function s:iterfuncs.hg.start(repo, opts, ...)
    return {'seen': [], 'state': [0, 0], 'opts': a:opts,
                \'showparents': get(a:000, 0, []), 'repo': a:repo}
endfunction
function s:iterfuncs.hg.proccs(d, cs)
    if has_key(a:d.opts.skipchangesets, a:cs.hex)
        let char='*'
        let text={'skip': 1}
        let skip=1
    else
        let char=((index(a:d.showparents, a:cs.hex)==-1)?('o'):('@'))
        let text=a:d.opts.templatefunc(a:cs, a:d.opts, a:d.repo)
        let skip=0
    endif
    call s:F.glog.utf(a:d.state, 'C', char, text,
                \     s:F.glog.utfedges(a:d.seen, a:cs.hex, a:cs.parents))
    if !has_key(text, 'text') || empty(text.text)
        return [[], 0, 0]
    endif
    if !skip
        return [text.text, text.block_r, text.special]
    else
        return [text.text, 0, 0]
    endif
endfunction
"▶1 temp
"▶2 s:templates
let s:templates={
            \'default': "Changeset $rev#suf:\:#$hex$branch#hide,pref: (branch ,suf:)#\n".
            \           "Commited $time by $user\n".
            \           "Tags: $tags\n".
            \           "Bookmarks: $bookmarks\n".
            \           "Files: $changes\n".
            \           "Renamed $renames\n".
            \           "Copied $copies\n".
            \           "$hide#@# $description\n".
            \           "$hide#$#$stat\n".
            \           "$hide#:#$patch\n".
            \           "$empty",
            \'hgdef':   "changeset:   $rev#suf:\:#$hex\n".
            \           "branch:      $branch\n".
            \           "tags:        $tags\n".
            \           "bookmarks:   $bookmarks\n".
            \           "user:        $user\n".
            \           "date:        $time#%a %b %d %H:%M:%S %Y#\n".
            \           "files:       $changes# #\n".
            \           "summary:     $summary\n".
            \           "$hide#$#$stat\n".
            \           "$hide#:#$patch\n".
            \           "$empty",
            \'hgdescr': "changeset:   $rev#suf:\:#$hex\n".
            \           "branch:      $branch\n".
            \           "tags:        $tags\n".
            \           "bookmarks:   $bookmarks\n".
            \           "user:        $user\n".
            \           "date:        $time#%a %b %d %H:%M:%S %Y#\n".
            \           "files:       $changes# #\n".
            \           "description:\n".
            \           "$description\n".
            \           "$hide#$#$stat\n".
            \           "$hide#:#$patch\n".
            \           "$empty",
            \'compact': "$rev$tags#pref:[,suf:]#   $hex $time#%Y-%m-%d %H:%M# $user\n".
            \           "  $summary\n".
            \           "$hide#$# $stat\n".
            \           "$hide#:#$patch\n".
            \           "$empty",
            \'cdescr':  "$rev$tags#pref:[,suf:]#   $hex $time#%Y-%m-%d %H:%M# $user\n".
            \           "  $description\n".
            \           "$hide#$# $stat\n".
            \           "$hide#:#$patch\n".
            \           "$empty",
            \'git':     "commit $hex\n".
            \           "Author: $user\n".
            \           "Date:   $time#%a %b %d %T %Y#\n".
            \           "$empty\n".
            \           "    $description\n".
            \           "$empty\n".
            \           "$hide#$# $stat\n".
            \           "$hide#:#$patch",
            \'gitoneline': "$hex $summary\n".
            \              "$hide#$# $stat\n".
            \              "$hide#:#$patch",
        \}
"▶2 s:kwexpr
" TODO Add bisection status
let s:kwexpr={}
let s:kwexpr.hide        = [0, '@0@', 0]
let s:kwexpr.empty       = [0, '@@@']
let s:kwexpr.hex         = [0, '@@@']
let s:kwexpr.branch      = [0, '@@@', 'keep']
let s:kwexpr.user        = [0, '@@@']
let s:kwexpr.rev         = [0, '@@@', 'ignore']
let s:kwexpr.time        = [0, 'strftime(@0@, @@@)', '%d %b %Y %H:%M']
let s:kwexpr.parents     = [0, 'join(@@@)']
let s:kwexpr.children    = [0, 'join(@@@)']
let s:kwexpr.tags        = [0, 'join(@@@, @0@)', ', ']
let s:kwexpr.bookmarks   = [0, 'join(@@@, @0@)', ', ']
let s:kwexpr.summary     = [0, '@@@']
" TODO Add tab expansion
let s:kwexpr.description = [1, 'split(@@@, "\n")']
let s:kwexpr.patch       = [1, '@@@']
let s:kwexpr.stat        = [2, 's:F.temp.stat(@@@, a:cs.files, @<@)']
let s:kwexpr.files       = [2, 's:F.temp.multlfmt(@@@, a:cs.files, '.
            \                                    '@<@, @0@, '.
            \                                    '"file")', ', ']
let s:kwexpr.changes     = [2, 's:F.temp.multlfmt(@@@, a:cs.changes, '.
            \                                    '@<@, @0@, '.
            \                                    '"file")', ', ']
let s:kwexpr.renames     = [2, 's:F.temp.renames(@@@, a:cs.files, '.
            \                                   '@<@, @0@)', ' to ']
let s:kwexpr.copies      = [2, 's:F.temp.renames(@@@, a:cs.files, '.
            \                                   '@<@, @0@)', ' to ']
let s:kwmarg={}
let s:kwmarg.summary='matchstr(a:cs.description, "\\\\v^[^\\n]*")'
let s:kwmarg.stat='a:repo.functions.getstats(a:repo, diff, a:opts)'
let s:kwmarg.patch='diff'
let s:kwmarg.empty=''''''
let s:kwpempt=['parents', 'children', 'tags', 'bookmarks']
let s:kwreg={
            \'rev' : '\d\+',
            \'parents': '\v\x{12,}( \x{12,})?',
            \'children': '\v\x{12,}( \x{12,})*',
        \}
let s:kwreqseqkw=['hex', 'branch', 'user', 'rev', 'time', 'parents', 'children',
            \     'tags', 'bookmarks', 'description', 'files', 'changes']
let s:kwreqs = {'stat': {'files': 1},
            \'renames': {'files': 1, 'renames': 1},
            \ 'copies': {'files': 1, 'copies': 1},
            \}
call map(s:kwreqseqkw, 'extend(s:kwreqs, {v:val : {v:val : 1}})')
unlet s:kwreqseqkw
"▶2 temp.stat :: stats, idxlist, linebeg → ([String], sp)
function s:F.temp.stat(stats, idxlist, linebeg)
    let sitems=map(sort(keys(a:stats.files)),
                \  '[v:val, '.
                \  'a:stats.files[v:val].insertions, '.
                \  'a:stats.files[v:val].deletions, '.
                \  's:_r.strdisplaywidth(v:val), '.
                \  'index(a:idxlist, v:val)]')
    let maxflen=max(map(copy(sitems), 'v:val[3]'))
    let maxilen=len(a:stats.insertions)
    let maxdlen=len(a:stats.deletions)
    let rt=[]
    let special={}
    for [file, ins, del, flen, fi] in sitems
        if fi!=-1
            let special['file00'.fi.'_l']=[len(rt), 0]
        endif
        let rt+=['  '.file.repeat(' ', maxflen-flen+1).'|'.
                    \ repeat(' ', maxilen-len(ins)+1).ins.
                    \ repeat(' ', maxdlen-len(del)+1).del]
    endfor
    let special.stat_R=[[0, 0], [len(rt), 0]]
    let rt+=[printf('%u files changed, %u insertions, %u deletions',
                \   len(keys(a:stats.files)),
                \   a:stats.insertions, a:stats.deletions)]
    call map(rt, 'a:linebeg.v:val')
    return [rt, special]
endfunction
"▶2 temp.renames :: renames, idxlist, linebeg, rensep → ([String], sp)
function s:F.temp.renames(renames, idxlist, linebeg, rensep)
    let rt=[]
    let special={}
    let rsl=len(a:rensep)
    for [cur, old] in items(filter(copy(a:renames), 'type(v:val)=='.type('')))
        let cl=len(rt)
        let fl=len(cur)
        let ol=len(old)
        let rt+=[a:linebeg.old.a:rensep.cur]
        let ll=len(rt[-1])
        let fi=index(a:idxlist, cur)
        let special['file0'.fi.'_r']=[[cl, ll-fl], [cl, ll-1]]
        let special['oldname'.fi.'_r']=[[cl, ll-fl-rsl-ol], [cl, ll-fl-rsl]]
        let special['rename'.fi.'_l']=[cl, 0]
    endfor
    return [rt, special]
endfunction
"▶2 temp.multlfmt :: list, idxlist, linebeg, itemsep, itemname → ([String], sp)
function s:F.temp.multlfmt(list, idxlist, linebeg, itemsep, itemname)
    let rt=[a:linebeg]
    let special={}
    let winwidth=winwidth(0)-10
    let linewidth=s:_r.strdisplaywidth(a:linebeg)
    let curfilenum=0
    let ii=-1
    let seplen=len(a:itemsep)
    for item in a:list
        let iwidth=s:_r.strdisplaywidth(item, linewidth)
        if curfilenum && iwidth+linewidth>winwidth
            let rt+=[a:linebeg.item.a:itemsep]
            let linewidth=s:_r.strdisplaywidth(rt[-1])
            let curfilenum=0
        else
            let rt[-1].=item.a:itemsep
            let linewidth+=iwidth
        endif
        let cl=len(rt)-1
        let ilen=len(item)
        let linelen=len(rt[-1])
        if a:list is a:idxlist
            let ii+=1
        else
            let ii=index(a:idxlist, item)
        endif
        let special[a:itemname.ii.'_r']=[[cl, linelen-ilen-seplen],
                    \                    [cl, linelen-seplen]]
        let curfilenum+=1
    endfor
    call map(rt, 'v:val[:-'.(seplen+1).']')
    return [rt, special]
endfunction
"▶2 temp.parsearg :: String → dict
function s:F.temp.parsearg(str)
    let s=a:str
    let r={}
    let i=0
    while !empty(s)
        let key=matchstr(s, '\v^%(expr|synreg|flbeg|pref|suf):')[:-2]
        if empty(key)
            let arg=matchstr(s, '\v(\\.|[^,])*')
            let s=s[len(arg)+1:]
            let r[i]=substitute(arg, '\v\\([\\:#,])', '\1', 'g')
            let i+=1
            continue
        endif
        let s=s[len(key)+1:]
        let arg=matchstr(s, '\v(\\.|[^,])*')
        let s=s[len(arg)+1:]
        let r[key]=substitute(arg, '\v\\([\\:#,])', '\1', 'g')
    endwhile
    return r
endfunction
"▶2 temp.parse :: String → template
let s:parsecache={}
function s:F.temp.parse(str)
    if has_key(s:parsecache, a:str)
        return s:parsecache[a:str]
    endif
    let s=a:str
    let r=[[[]]]
    let lr=r[-1]
    let t=lr[0]
    while !empty(s)
        let lit=matchstr(s, "\\v^[^$\n]*")
        let t+=[lit]
        let s=s[len(lit):]
        let c=s[0]
        let s=s[1:]
        if empty(s)
            break
        endif
        if c is# "\n"
            let r+=[[[]]]
            let lr=r[-1]
            let t=lr[0]
            continue
        endif
        let kw=matchstr(s, '\v^\w+')
        let s=s[len(kw):]
        if !has_key(s:kwexpr, kw)
            if len(t)>1
                let t[-2].=remove(t, -1)
            endif
            continue
        endif
        let astr=matchstr(s, '\v^\#(\\.|[^#])+\#')
        let arg=s:F.temp.parsearg(astr[1:-2])
        let j=0
        for a in s:kwexpr[kw][2:]
            let a=get(arg, j, a)
            if a is 0
                call s:_f.throw('argmis', j, kw)
            endif
            let arg[j]=a
            let j+=1
        endfor
        if s:kwexpr[kw][0] && !empty(filter(lr[1:], 's:kwexpr[v:val[0]][0]'))
            call s:_f.throw('2multl')
        endif
        let s=s[len(astr):]
        let lr+=[[kw, arg]]
    endwhile
    let s:parsecache[a:str]=r
    return r
endfunction
"▶2 temp.skip
function s:F.temp.skip(meta, opts)
    for kw in map(copy(a:meta), 'v:val[0]')
        if (!get(a:opts, 'showfiles', 0) &&
                    \   (kw is# 'files' || kw is# 'changes')) ||
                    \(!get(a:opts, 'showrenames', 0) && kw is# 'renames') ||
                    \(!get(a:opts, 'showcopies',  0) && kw is# 'copies')  ||
                    \(!get(a:opts, 'patch',       0) && kw is# 'patch')   ||
                    \(!get(a:opts, 'stat',        0) && kw is# 'stat')
            return 1
        endif
    endfor
    return 0
endfunction
"▶2 temp.getcid
function s:F.temp.getcid(template, opts)
    let r=''
    for o in ['patch', 'stat', 'showfiles', 'showrenames', 'showcopies']
        let r.=get(a:opts, o, 0)
    endfor
    let r.=has_key(a:opts, 'files')
    let r.=string(a:template)[2:-3]
    return r
endfunction
"▶2 temp.compile :: template, opts → Fref
let s:compilecache={}
function s:F.temp.compile(template, opts, repo)
    "▶3 Cache
    let cid=s:F.temp.getcid(a:template, a:opts)
    if has_key(s:compilecache, cid)
        return s:compilecache[cid]
    endif
    "▶3 Define variables
    let func=['function d.template(cs, opts, repo)',
                \'let r={"text": [], "special": {}}',
                \'let text=r.text',
                \'let special=r.special',]
    let hasfiles=has_key(a:opts, 'files')
    if hasfiles
        let func+=['let files=a:opts.csfiles[a:cs.hex]']
    endif
    let hasrevisions=get(a:repo, 'hasrevisions', 1)
    if get(a:opts, 'patch', 0) || get(a:opts, 'stat', 0)
        let filesarg=((hasfiles && !has_key(a:opts.ignorefiles, 'patch'))?
                    \   ('files'):
                    \   ('[]'))
        let func+=['if !empty(a:cs.parents)',
                    \'let diff=a:repo.functions.diff(a:repo, '.
                    \                               'a:cs.hex, '.
                    \                               'a:cs.parents[0], '.
                    \                                filesarg.', '.
                    \                               'a:opts)',
                    \'endif']
    endif
    let reqs={}
    "▲3
    for [lit; meta] in a:template
        if s:F.temp.skip(meta, a:opts)
            continue
        endif
        let addedif=0
        let lmeta=len(meta)
        if lmeta
            let kw=meta[0][0]
            let lkw=meta[-1][0]
        endif
        "▶3 Skip line under certain conditions
        if !lmeta
        elseif lmeta==1 && !s:kwexpr[meta[0][0]][0]
            if index(s:kwpempt, kw)!=-1
                let addedif=1
                let func+=['if !empty(a:cs.'.kw.')']
            elseif kw is# 'branch'
                let addedif=1
                let func+=['if a:cs.branch isnot# "default"']
            elseif kw is# 'rev' && !hasrevisions
                continue
            endif
            let func+=['let special.'.meta[0][0].'_l=[len(text), 0]']
        elseif lkw is# 'patch' || lkw is# 'stat'
            let addedif=1
            let func+=['if exists("diff")']
        elseif lkw is# 'files' || lkw is# 'changes'
            let addedif=1
            let func+=['if !empty(a:cs.'.kw.')']
        endif
        "▲3
        let func+=['let text+=[""]']
        let i=-1
        for str in lit
            let i+=1
            if !empty(str)
                let func+=['let text[-1].='.string(str)]
            endif
            if lmeta>i
                "▶3 Define variables
                let [kw, arg]=meta[i]
                let ke=s:kwexpr[kw]
                "▶3 Get expression
                if has_key(arg, 'expr')
                    let expr=arg.expr
                else
                    let expr=ke[1]
                endif
                "▶4 Determine what should be used as {word} argument
                if has_key(s:kwmarg, kw)
                    let marg=s:kwmarg[kw]
                elseif hasfiles && (kw is# 'files' || kw is# 'changes') &&
                            \!has_key(a:opts.ignorefiles, 'files')
                    let marg='files'
                elseif hasfiles && (kw is# 'renames' || kw is# 'copies') &&
                            \!has_key(a:opts.ignorefiles, kw)
                    let marg='filter(copy(a:cs.'.kw.'), '.
                                \   '"index(files, v:val)!=-1")'
                else
                    let marg='a:cs.'.kw
                endif
                "▲4
                let expr=substitute(expr, '@@@', marg, 'g')
                "▶3 Process positional parameters
                for j in range(len(ke)-2)
                    let expr=substitute(expr, '@'.j.'@',
                                \       escape(string(arg[j]), '&~\'), 'g')
                endfor
                "▶3 Skip meta if required
                if kw is# 'rev' && !hasrevisions && arg.0 isnot# 'keep'
                    continue
                endif
                "▶3 Add requirements information
                if has_key(s:kwreqs, kw)
                    call extend(reqs, s:kwreqs[kw])
                endif
                "▶3 Add complex multiline statement
                let addedif2=0
                if ke[0]==2
                    "▶4 Add missing if’s
                    if !addedif
                        if kw is# 'stat'
                            let addedif2=1
                            let func+=['if exists("diff")']
                        elseif kw is# 'files' || kw is# 'changes'
                            let addedif2=1
                            let func+=['if !empty(a:cs.'.kw.')']
                        endif
                    endif
                    "▲4
                    let expr=substitute(expr, '@<@', 'lstr', 'g')
                    let func+=['let lstr=remove(text, -1)',
                                \'let [ntext, sp]='.expr]+
                                \   (has_key(arg, 'flbeg')?
                                \       ['let ntext[0]='.string(arg.flbeg).
                                \                                  '.ntext[0]']:
                                \       [])+[
                                \'call s:F.glog.addlines(sp, len(text))',
                                \'let text+=ntext',
                                \'call extend(special, sp)']
                "▶3 Add simple multiline statement
                elseif ke[0]
                    "▶4 Add missing if’s
                    if !addedif && kw is# 'patch'
                        let addedif2=1
                        let func+=['if exists("diff")']
                    endif
                    "▲4
                    let func+=['let ntext='.expr,
                                \'call map(ntext, '.
                                \         'string(remove(text, -1)).".v:val")']+
                                \   (has_key(arg, 'flbeg')?
                                \       ['let ntext[0]='.string(arg.flbeg).
                                \                                  '.ntext[0]']:
                                \       [])+[
                                \'let special.'.kw.'_R=[[len(text), 0], '.
                                \                '[len(text)+len(ntext)-1, 0]]',
                                \'let text+=ntext']
                "▶3 Add single-line statement
                else
                    if kw is# 'branch' && arg.0 isnot# 'keep'
                        let func+=['if a:cs.branch isnot# "default"']
                    endif
                    let func+=['let estr='.expr]
                    "▶4 Add suffix or prefix
                    if index(s:kwpempt, kw)!=-1
                        let condition='!empty(estr)'
                    elseif kw is# 'branch'
                        let condition='estr isnot# "default"'
                    elseif kw is# 'rev'
                        let condition=0
                    endif
                    if exists('condition')
                        let addif=(condition isnot 0) &&
                                    \(has_key(arg, 'pref') ||
                                    \ has_key(arg, 'suf'))
                        if addif
                            let func+=['if '.condition]
                        endif
                        if has_key(arg, 'pref')
                            let func+=['let estr='.string(arg.pref).'.estr']
                        endif
                        if has_key(arg, 'suf')
                            let func+=['let estr.='.string(arg.suf)]
                        endif
                        if addif
                            let func+=['endif']
                        endif
                    endif
                    "▲4
                    let func+=['let special.'.kw.'_r='.
                                \  '[[len(text)-1, len(text[-1])], '.
                                \   '[len(text)-1, len(text[-1])+len(estr)-1]]',
                                \'let text[-1].=estr',]
                    if kw is# 'branch' && arg.0 isnot# 'keep'
                        let func+=['endif']
                    endif
                endif
                "▲3
                if addedif2
                    let func+=['endif']
                endif
            endif
        endfor
        if addedif
            let func+=['endif']
        endif
    endfor
    let func+=['return r',
                \'endfunction']
    let d={}
    execute join(func, "\n")
    let r=[reqs, d.template]
    let s:compilecache[cid]=r
    return r
endfunction
"▶2 temp.addgroup
function s:F.temp.addgroup(r, nlgroups, group)
    let i=0
    for [line, lnr] in filter(map(copy(a:r), '[v:val, v:key]'),
                \             'stridx(",=", v:val[0][-1:])!=-1')
        let a:r[lnr].=a:group
        let i+=1
    endfor
    if !i
        call add(a:nlgroups, a:group)
    endif
endfunction
"▶2 temp.syntax :: template, opts → [VimCommand] + :syn
"▶3 Some globals
let s:syncache={}
let s:noargtimereg='\v\d\d \S+ \d{4,} \d\d:\d\d'
let s:ukntkws=['c', 'x', 'X', '+']
let s:timekwregs={
            \'a': '\S\{1,3}',
            \'A': '\S\+',
            \'b': '\S\{1,3}',
            \'B': '\S\+',
            \'C': '\d\d',
            \'d': '\d\d',
            \'D': '\d\d\/\d\d\/\d\d',
            \'e': '\[1-3 ]\d',
            \'F': '\d\{4,}-\d\d-\d\d',
            \'G': '\d\{4,}',
            \'g': '\d\d',
            \'h': '\S\{1,3}',
            \'H': '\d\d',
            \'I': '\d\d',
            \'j': '\d\{3}',
            \'k': '\[12 ]\d',
            \'l': '\[1 ]\d',
            \'m': '\d\d',
            \'M': '\d\d',
            \'n': '\n',
            \'p': '\[AP]M',
            \'P': '\[ap]m',
            \'r': '\d\d:\d\d:\d\d \[AP]M',
            \'R': '\d\d:\d\d',
            \'s': '\d\+',
            \'S': '\d\d',
            \'t': '\t',
            \'T': '\d\d:\d\d:\d\d',
            \'u': '\[1-7]',
            \'U': '\d\d',
            \'V': '\d\d',
            \'w': '\[0-6]',
            \'W': '\d\d',
            \'y': '\d\d',
            \'Y': '\d\{4,}',
            \'z': '\[+\-]\d\{4}',
            \'Z': '\S\{3}',
            \'%': '%',
        \}
"▲3
function s:F.temp.syntax(template, opts, repo)
    "▶3 Cache
    let cid=s:F.temp.getcid(a:template, a:opts)
    if has_key(s:syncache, cid)
        return s:syncache[cid]
    endif
    "▶3 Define variables
    let r=[]
    let topgroups=[]
    let hasrevisions=get(a:repo, 'hasrevisions', 1)
    "▲3
    let r+=['syn match auLogFirstLineStart =\v^[^ ]*[@o][^ ]* = '.
                \'skipwhite nextgroup=']
    let i=0
    let nlgroups=[]
    for [lit; meta] in a:template
        if s:F.temp.skip(meta, a:opts)
            continue
        endif
        let lmeta=len(meta)
        let llit=len(lit)
        let j=0
        let hasmult=0
        for str in lit
            if !empty(str)
                if lmeta>j
                    let skname='SkipBefore_'.meta[j][0]
                else
                    let skname='Text'.i
                endif
                let skname='auLog'.skname
                call s:F.temp.addgroup(r, nlgroups, skname)
                let r+=['syn match '.skname.' ']
                if lmeta>j
                    let r[-1].='/\V'.escape(str, '\/').'/'
                else
                    let r[-1].='/\v.*/'
                endif
                let r[-1].=' contained nextgroup='
            endif
            if lmeta>j
                let [kw, arg]=meta[j]
                if s:kwexpr[kw][0]
                    let hasmult=1
                endif
                if kw is# 'empty' || (kw is# 'rev' && !hasrevisions &&
                            \         arg.0 isnot# 'keep')
                    let r[-1]=substitute(r[-1], '\v\w+$', '', '')
                elseif has_key(arg, 'synreg')
                    call s:F.temp.addgroup(r, nlgroups, 'auLog_'.kw)
                    let r+=['syn match auLog_'.kw.' /'.arg.synreg.'/ '.
                                \'contained nextgroup=']
                elseif kw is# 'hex'
                    call s:F.temp.addgroup(r, nlgroups, 'auLogHexStart')
                    let r+=['syn match auLogHexStart /\v\x{12}/ contained'.
                                \' nextgroup=auLogHexEnd',
                            \'syn match auLogHexEnd /\v\x+/ contained '.
                            \   (has('conceal')?('conceal'):('')).' nextgroup=']
                elseif kw is# 'patch'
                    call s:F.temp.addgroup(r, nlgroups,
                                \'auLogPatchAdded,auLogPatchRemoved,'.
                                \'auLogPatchFile,auLogPatchNewFile,'.
                                \'auLogPatchOldFile,auLogPatchOther,'.
                                \'auLogPatchNotModified,'.
                                \'auLogPatchChunkHeader')
                    let newr=[   'Added   /\V+\.\*/',
                                \'Removed /\V-\.\*/',
                                \'File    /\vdiff.*/',
                                \'NewFile /\V+++ \.\*/',
                                \'OldFile /\V--- \.\*/',
                                \'NotModified  / \v.*/',
                                \'ChunkHeader /@\v.*/ contains=auLogPatchSect',
                                \'Sect    /\V @@\.\+/ms=s+3',
                                \]
                    call map(newr, '"syn match auLogPatch".v:val.'.
                                \  '" contained skipnl '.
                                \    'nextgroup=auLogNextLineStart"')
                    let r+=newr
                elseif kw is# 'stat'
                    call s:F.temp.addgroup(r, nlgroups,
                                \'auLogStatFiles,auLogStatFileSep')
                    let newr=[   'Files /\v\d+/ nextgroup=auLogStatFilesMsg',
                                \'FilesMsg / files changed, / '.
                                \              'nextgroup=auLogStatIns',
                                \'Ins /\v\d+/ nextgroup=auLogStatInsMsg',
                                \'InsMsg / insertions, / '.
                                \               'nextgroup=auLogStatDel',
                                \'Del /\v\d+/ nextgroup=auLogStatDelMsg',
                                \'DelMsg / deletions/ skipnl '.
                                \           'nextgroup=auLogNextLineStart',
                                \'FileSep /  / nextgroup=auLogStatFile',
                                \'File /\v%(%(\ \|\ )@!.)+/ '.
                                \             'nextgroup=auLogStatTSep',
                                \'TSep /\v\s+\|\s+/ nextgroup=auLogStatTIns',
                                \'TIns /\v\d+/ nextgroup=auLogStatTNumSep',
                                \'TNumSep /\v\s+/ nextgroup=auLogStatTDel',
                                \'TDel /\v\d+/ skipnl '.
                                \           'nextgroup=auLogNextLineStart']
                    call map(newr, '"syn match auLogStat".v:val.'.
                                \  '" contained"')
                    let r+=newr
                elseif kw is# 'hide'
                    let sname='auLog_hide'.i.'_'.j
                    call s:F.temp.addgroup(r, nlgroups, sname)
                    let r+=['hi def link '.sname.' Ignore']
                    let r+=['syn match '.sname.' /\V'.escape(arg[0], '\/').'/ '.
                                \'contained nextgroup=']
                elseif (index(s:kwpempt, kw)!=-1 || kw is# 'branch' ||
                            \                       kw is# 'rev') &&
                            \(has_key(arg, 'pref') || has_key(arg, 'suf'))
                    if has_key(arg, 'pref')
                        call s:F.temp.addgroup(r,nlgroups,'auLog_'.kw.'_pref,')
                        let r+=['syn match auLog_'.kw.'_pref '.
                                    \'/\V'.escape(arg.pref, '\/').'/ '.
                                    \'contained nextgroup=auLog_'.kw]
                    else
                        call s:F.temp.addgroup(r, nlgroups, 'auLog_'.kw.',')
                    endif
                    let nextlit=get(arg, 'suf', get(lit, j+1, 0))
                    let r+=['syn match auLog_'.kw.' '.
                                \'/'.s:F.getkwreg(kw, nextlit).'/ '.
                                \'contained nextgroup=']
                    if has_key(arg, 'suf')
                        let r[-1].='auLog_'.kw.'_suf'
                        let r+=['syn match auLog_'.kw.'_suf '.
                                    \'/\V'.escape(arg.suf, '\/').'/ '.
                                    \'contained nextgroup=']
                    endif
                elseif lmeta==j+1 && llit<=j+1
                    call s:F.temp.addgroup(r, nlgroups, 'auLog_'.kw)
                    let r+=['syn match auLog_'.kw.' /\v.*/ '.
                                \'contained nextgroup=']
                elseif kw is# 'time'
                    call s:F.temp.addgroup(r, nlgroups, 'auLog_'.kw)
                    if has_key(arg, 0)
                        if j<=llit && !empty(lit[j+1])
                            let creg='\%(\%('.escape(lit[j+1], '\/').'\)\@!'.
                                        \'\.\)\*'
                        else
                            let creg='\.\*'
                        endif
                        let reg='\V'.substitute(escape(arg.0, '\/'), '\v\%(.)',
                                    \'\=index(s:ukntkws, submatch(1))==-1 ?'.
                                    \   'get(s:timekwregs, submatch(1), '.
                                    \       'submatch(0)) :'.
                                    \   'creg', 'g')
                    else
                        let reg=s:noargtimereg
                    endif
                    let r+=['syn match auLog_time '.
                                \'/'.reg.'/ '.
                                \'contained nextgroup=']
                else
                    call s:F.temp.addgroup(r, nlgroups, 'auLog_'.kw)
                    let r+=['syn match auLog_'.kw.' /'.
                                \s:F.getkwreg(kw, get(lit, j+1, 0)).'/ '.
                                \'contained nextgroup=']
                endif
            endif
            let j+=1
        endfor
        call s:F.temp.addgroup(r, nlgroups, 'auLogNextLineStart')
        let r[-1].=' skipnl'
        let i+=1
    endfor
    if !empty(nlgroups)
        let r+=['syn match auLogNextLineStart @\v^[^ ]+ @ skipwhite '.
                    \' nextgroup='.join(nlgroups, ',')]
    endif
    call add(r, remove(r, 0))
    if len(r)==1
        return []
    endif
    let s:syncache[cid]=r
    return r
endfunction
"▶1 comparedates :: datesel, time → -1|0|1
let s:datechars='YmdHM'
function s:F.comparedates(datesel, time)
    let j=0
    for selnum in a:datesel
        if selnum isnot# '*'
            let spec='%'.s:datechars[j]
            if selnum is# '.'
                let selnum=str2nr(strftime(spec))
            endif
            let actnum=str2nr(strftime(spec, a:time))
            if actnum!=selnum
                if actnum<selnum
                    return -1
                else
                    return 1
                endif
            endif
        endif
        let j+=1
    endfor
    return 0
endfunction
"▶1 iterfuncs.check
" startfunc (here)  :: repo, opts → d
let s:fcheckpropslist=['renames', 'copies', 'changes', 'files']
let s:iterfuncs.check={}
"▶2 iterfuncs.check.start
"▶3 addcentury
function s:F.addcentury(year)
    if type(a:year)==type(0) && a:year<100
        let curyear=str2nr(strftime('%y'))
        let century=str2nr(strftime('%Y')[:-3])
        if a:year<=curyear
            let r=((century*100)+a:year)
        else
            let r=(((century-1)*100)+a:year)
        endif
        return r
    endif
    return a:year
endfunction
"▶3 redate
function s:F.redate(datespec)
    let date=map(split(a:datespec, '\v[^0-9*.]+'),
                \'v:val=~#"\\d" ? str2nr(v:val) : v:val')
    let date[0]=s:F.addcentury(date[0])
    return date
endfunction
"▲3
let s:keytoexpr={
            \'branch': '"a:cs.branch isnot# ".string(v:val)',
            \'merges': '(v:val)?("len(a:cs.parents)<=1"):'.
            \                  '("len(a:cs.parents)>1")',
            \'search': '"a:cs.description!~#".string(v:val)',
            \  'user':        '"a:cs.user!~#".string(v:val)',
        \}
function s:iterfuncs.check.start(repo, opts)
    let r={'repo': a:repo, 'hasfiles': 0, 'hasdaterange': 0, 'hasdate': 0}
    "▶3 Define variables for files filtering
    if has_key(a:opts, 'files')
        let r.hasfiles=1
        let r.csfiles={}
        let r.filepats=a:opts.filepats
        let r.tocheck={}
        let a:opts.csfiles=r.csfiles
    endif
    "▶3 Define variables for date filtering
    if has_key(a:opts, 'date')
        let idx=match(a:opts.date, '\V<=\?>')
        if idx==-1
            let r.hasdate=1
            let r.selector=(stridx('<>', a:opts.date[0])==-1)?(''):
                        \                                     (a:opts.date[0])
            let r.acceptexact=(empty(r.selector) || a:opts.date[1] is# '=')
            let r.date=s:F.redate(a:opts.date[empty(r.selector)?(0):
                        \                     (len(r.selector)+r.acceptexact):])
        else
            let r.hasdaterange=1
            let r.date1=s:F.redate(a:opts.date[:(idx-1)])
            let r.acceptexact=(a:opts.date[idx+1] is# '=')
            let r.date2=s:F.redate(a:opts.date[(idx+2+r.acceptexact):])
        endif
    endif
    "▶3 Determine other filters
    let r.expr=join(values(map(filter(copy(a:opts),
                \                     'has_key(s:keytoexpr, v:key)'),
                \              'eval(s:keytoexpr[v:key])')), '||')
    "▲3
    return r
endfunction
"▶2 iterfuncs.check.check
function s:iterfuncs.check.check(d, cs)
    "▶3 Check simple cases
    if !empty(a:d.expr) && eval(a:d.expr)
        return 0
    endif
    "▶3 Check files
    if a:d.hasfiles
        let copies =a:d.repo.functions.getcsprop(a:d.repo, a:cs, 'copies' )
        let renames=a:d.repo.functions.getcsprop(a:d.repo, a:cs, 'renames')
        let changes=a:d.repo.functions.getcsprop(a:d.repo, a:cs, 'changes')[:]
        let csfiles=[]
        let tcfiles=[]
        let a:d.csfiles[a:cs.hex]=csfiles
        if has_key(a:d.tocheck,a:cs.hex)
            let tc=a:d.tocheck[a:cs.hex]
            call filter(changes, '(index(tc, v:val)==-1)?(1):'.
                        \           '([0, add(csfiles, v:val)][0])')
            call filter(tc, 'index(csfiles, v:val)==-1')
            if !empty(tc)
                let allfiles=a:d.repo.functions.getcsprop(a:d.repo, a:cs,
                            \                             'allfiles')
                let tcfiles+=filter(copy(allfiles), 'index(tc, v:val)!=-1')
            endif
        endif
        for pattern in a:d.filepats
            let newchanges=[]
            call map(copy(changes), 'add(((v:val=~#'.string(pattern).')?'.
                        \                   '(csfiles):'.
                        \                   '(newchanges)), v:val)')
            if empty(newchanges)
                break
            endif
            let changes=newchanges
        endfor
        for file in csfiles
            let tcfiles+=map(filter(['renames', 'copies'],
                        \           'has_key({v:val}, file) && '.
                        \           '{v:val}[file] isnot 0'),
                        \    '{v:val}[file]')
        endfor
        if !empty(tcfiles)
            call map(copy(a:cs.parents), 'extend(a:d.tocheck, '.
                        \'{v:val : get(a:d.tocheck, v:val, [])+tcfiles})')
        endif
        if empty(csfiles)
            return 0
        endif
    endif
    "▶3 Check date
    if a:d.hasdate
        let cmpresult=s:F.comparedates(a:d.date, a:cs.time)
        if !((a:d.acceptexact && cmpresult==0) ||
                    \(a:d.selector is# '<' && cmpresult==-1) ||
                    \(a:d.selector is# '>' && cmpresult==1))
            return 0
        endif
    elseif a:d.hasdaterange
        let cmp1result=s:F.comparedates(a:d.date1, a:cs.time)
        let cmp2result=s:F.comparedates(a:d.date2, a:cs.time)
        if !((cmp1result==1 && cmp2result==-1) ||
                    \(a:d.acceptexact && (cmp1result==0 ||
                    \                     cmp2result==0)))
            return 0
        endif
    endif
    "▲3
    return 1
endfunction
"▶1 gettemplate :: bvar → + bvar
function s:F.gettemplatelist(bvar)
    if has_key(a:bvar, 'templatelist')
        return
    endif
    if has_key(a:bvar.opts, 'template')
        let template=eval(a:bvar.opts.template)
    elseif has_key(a:bvar.opts, 'style')
        let template=s:templates[a:bvar.opts.style]
    else
        let template=s:templates.default
    endif
    let a:bvar.templatelist=s:F.temp.parse(template)
endfunction
"▶1 getblock :: bvar + cursor, bvar → block
"▶2 bisect :: [a], function + self → a
function s:F.bisect(list, function)
    let llist=len(a:list)
    let lborder=0
    let rborder=llist-1
    let lres=call(a:function, [a:list[lborder]], self)
    if lres<=0
        return a:list[lborder]
    endif
    let rres=call(a:function, [a:list[rborder]], self)
    if rres>=0
        return a:list[rborder]
    endif
    let totest='r'
    let cur=(((rborder+1)/2)-1)
    while lborder!=rborder
        let res=call(a:function, [a:list[cur]], self)
        if res==0
            return a:list[cur]
        else
            let shift=((rborder-lborder)/2)
            if shift==0
                let shift=1
            endif
            let {(res>0)?('l'):('r')}border=cur
            let cur=lborder+shift
        endif
    endwhile
    return a:list[lborder]
endfunction
"▶2 checkinblock :: block → -1|0|1
function s:F.checkinblock(block)
    let curline=line('.')-1
    return       ((curline<a:block[0][0])?(-1):
                \((curline>a:block[1][0])?( 1):
                \                         ( 0)))
endfunction
"▲2
function s:F.getblock(bvar)
    if empty(a:bvar.rectangles)
        call s:_f.throw('nocontents')
    endif
    return s:F.bisect(a:bvar.rectangles, s:F.checkinblock)
endfunction
"▶1 setup
"▶2 getkwreg
function s:F.getkwreg(kw, nextlit)
    if has_key(s:kwreg, a:kw)
        return s:kwreg[a:kw]
    " XXX 0 is empty
    elseif !empty(a:nextlit)
        return '\V\%(\%('.escape(a:nextlit, '\/').'\)\@!\.\)\*'
    else
        return '.*'
    endif
endfunction
"▲2
function s:F.setup(read, repo, opts, ...)
    let opts=a:opts
    let bvar=get(a:000, 0, {'opts': opts})
    let bvar.getblock=s:F.getblock
    "▶2 Add `ignorefiles'
    let ignorefiles=(has_key(opts, 'ignfiles')?
                \               (opts.ignfiles):
                \               (s:_f.getoption('ignorefiles')))
    let opts.ignorefiles={}
    call map(copy(ignorefiles), 'extend(opts.ignorefiles, {v:val : 1})')
    unlet ignorefiles
    "▶2 Get cslist
    let csiterfuncsname=((has_key(opts, 'revision'))?
                \          ('ancestors'):
                \       ((has_key(opts, 'revrange'))?
                \          ('revrange')
                \       :
                \          ('changesets')))
    let csiterfuncs=a:repo.iterfuncs[csiterfuncsname]
    "▶2 Get template
    call s:F.gettemplatelist(bvar)
    let [opts.reqs, opts.templatefunc]=s:F.temp.compile(bvar.templatelist, opts,
                \                                       a:repo)
    "▲2
    if !a:read
        let buf=bufnr('%')
        let bvar.procinput=(has_key(a:opts, 'procinput')?
                    \           (2*a:opts.procinput):
                    \           s:_f.getoption('procinput'))
        if bvar.procinput==1 && getchar(1)
            let bvar.procinput=0
        endif
    endif
    let bvar.cw=s:_f.getoption('closewindow')
    let text=s:F.glog.graphlog(a:repo, opts, csiterfuncs, bvar, a:read)
    if a:read
        call s:_r.setlines(text, a:read)
    elseif bufnr('%')==buf
        setlocal readonly nomodifiable
    endif
    return bvar
endfunction
"▶1 syndef
function s:F.syndef()
    let buf=+expand('<abuf>')
    if !has_key(s:_r.bufvars, buf)
        return
    endif
    let bvar=s:_r.bufvars[buf]
    call s:F.gettemplatelist(bvar)
    let bvar.templatesyn=s:F.temp.syntax(bvar.templatelist,bvar.opts,bvar.repo)
    for line in bvar.templatesyn
        execute line
    endfor
endfunction
augroup AuLogSyntax
    autocmd Syntax aurumlog :call s:F.syndef()
augroup END
let s:_augroups+=['AuLogSyntax']
"▶1 logfunc
function s:logfunc.function(repopath, opts)
    let opts=copy(a:opts)
    if has_key(opts, 'files')
        if opts.files[0] is# ':'
            let curfile=s:_r.cmdutils.getrrf(opts, 'nocurf', 'getfile')[3]
            if curfile is 0
                call remove(opts.files, 0)
            else
                let opts.files[0]=s:_r.cmdutils.globescape(curfile)
            endif
        endif
        if a:repopath is# ':'
            let repo=s:_r.repo.get(opts.files[0])
        else
            let repo=s:_r.repo.get(a:repopath)
        endif
        call map(opts.files, 'repo.functions.reltorepo(repo, v:val)')
    else
        let repo=s:_r.repo.get(a:repopath)
    endif
    call s:_r.cmdutils.checkrepo(repo)
    if has_key(opts, 'cmd')
        let cmd=remove(opts, 'cmd')
    else
        let cmd='silent new'
    endif
    call s:_r.run(cmd, 'log', repo, opts)
    if !has_key(opts, 'cmd')
        setlocal bufhidden=wipe
    endif
endfunction
let s:datereg='%(\d\d%(\d\d)?|[*.])'.
            \ '%(\-%(\d\d?|[*.])'.
            \ '%(\-%(\d\d?|[*.])'.
            \ '%([ _]%(\d\d?|[*.])'.
            \ '%(\:%(\d\d?|[*.]))?)?)?)?'
let s:logfunc['@FWC']=['-onlystrings '.
            \          '['.s:_r.cmdutils.nogetrepoarg.']'.
            \          '{ *?files    (type "")'.
            \          '  *?ignfiles in [patch renames copies files] ~start'.
            \          '   ?date     match /\v[<>]?\=?'.s:datereg.'|'.
            \                                 s:datereg.'\<\=?\>'.s:datereg.'/'.
            \          '   ?search   isreg'.
            \          '   ?user     isreg'.
            \          '   ?branch   type ""'.
            \          '   ?limit    range 1 inf'.
            \          '   ?revision type ""'.
            \          ' +2?revrange type "" type ""'.
            \          '   ?style    key templates'.
            \          '   ?template idof variable'.
            \          '  !?merges'.
            \          '  !?patch'.
            \          '  !?stat'.
            \          '  !?showfiles'.
            \          '  !?showrenames'.
            \          '  !?showcopies'.
            \          '  !?procinput'.
            \          s:_r.repo.diffoptsstr.
            \          '   ?cmd      type ""'.
            \          '}', 'filter']
call add(s:logcomp, substitute(substitute(
            \substitute(substitute(substitute(substitute(s:logfunc['@FWC'][0],
            \'\V|*_r.repo.get',        '',                                  ''),
            \'\vfiles\s+\([^)]*\)',    'files path',                        ''),
            \'\Vcmd\s\+type ""',       'cmd first (in cmds, idof command)', ''),
            \'\vrevision\s+\Vtype ""', 'revision '.s:_r.comp.rev,           ''),
            \'\vbranch\s+\Vtype ""',   'branch '.s:_r.comp.branch,          ''),
            \'\vrevrange\s+\Vtype "" type ""',
            \                         'revrange '.s:_r.comp.rev.' '.
            \                                     s:_r.comp.rev,            ''))
"▶1 Create aurum://log
call s:_f.newcommand({
            \'function': s:F.setup,
            \ 'options': {'list': ['files', 'revrange', 'ignfiles'],
            \             'bool': ['merges', 'patch', 'stat', 'showfiles',
            \                      'showrenames', 'showcopies', 'procinput'],
            \              'num': ['limit']+s:_r.repo.diffoptslst,
            \              'str': ['date', 'search', 'user', 'branch',
            \                      'revision', 'style', 'template',
            \                      'crrestrict'],
            \             'pats': ['files'],
            \            },
            \'filetype': 'aurumlog',
            \'requiresbvar': 1,
            \})
"▶1
call frawor#Lockvar(s:, '_r,_pluginloaded,compilecache,parsecache,syncache')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
