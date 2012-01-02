Rem
Rem
Rem     ______     __         ______     ______     __  __     ______     ______     __  __    
Rem    /\  == \   /\ \       /\  __ \   /\  ___\   /\ \/ /    /\  == \   /\  __ \   /\_\_\_\   
Rem    \ \  __<   \ \ \____  \ \  __ \  \ \ \____  \ \  _"-.  \ \  __<   \ \ \/\ \  \/_/\_\/_  
Rem     \ \_____\  \ \_____\  \ \_\ \_\  \ \_____\  \ \_\ \_\  \ \_____\  \ \_____\   /\_\/\_\ 
Rem      \/_____/   \/_____/   \/_/\/_/   \/_____/   \/_/\/_/   \/_____/   \/_____/   \/_/\/_/ 
Rem                                                                                            
Rem
Rem
Rem    NAME
Rem      bx.sql - usable SQL*Plus
Rem
Rem    AUTHOR
Rem      Przemyslaw Piotrowski
Rem      github.com/wski/blackbox
Rem
Rem
Rem    USAGE
Rem      @bx <query>[;param1=value1[;param2=value2[...]]] <filter>
Rem      
Rem      query     - name of the embedded query or any SQL enclosed with "" 
Rem                  or just any table/view
Rem      paramN    - parameter name within one of the following:
Rem                      s (sort)       - custom sort (e.g. "sid,seq#", "1,3,5", "-id")
Rem                      c (columns)    - show given columns only (with auto GROUP BY when 
Rem                                       aggregates detected)
Rem                      n (top-n)      - show only n rows of default or supplied order
Rem                                       (3/sid/-time_waited will do top-3 partitioned by sid)
Rem                      w (where)      - additional WHERE condition on aliased columns
Rem                      g (graph)      - graph given columns or expressions
Rem                      i (instance)   - show given instances only (RAC, eg. 1,2,3)
Rem                      h (humanize)   - enable readable numbers (default 'y')
Rem         (NOT YET)    r (repeat)     - repeat query every r seconds (aka. 'watch')
Rem                      t (time)       - time range for AWR/historical queries 
Rem                                       or snapshot id ("-5d:-2d", ":-7h", "9870:9890")
Rem         (NOT YET)    d (delta)      - difference against previous snapshot 
Rem
Rem      valueN    - value of the parameter (optionally enclosed with double quotes)
Rem      filter    - grep expression for result grid (invisible cell separator is ;)
Rem                  ... can also be a list of IDs from ID_ alias or regular
Rem                  query "select sid from v$mystat"
Rem
Rem
Rem    DISCLAIMER
Rem      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
Rem      EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
Rem      OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
Rem      NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
Rem      HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
Rem      WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
Rem      FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE 
Rem      OR OTHER DEALINGS IN THE SOFTWARE. 
Rem

set term off lin 180 def '&' trimsp on trimout on 
set pages 0 emb on newp none

var vsc clob
var vtc clob
var vnc clob

begin
:vsc := 'BLOCK_SIZE,BYTES,DATAFILES,DELTA_INTERCONNECT_IO_BYTES,DELTA_READ_IO_BYTES,DELTA_WRITE_IO_BYTES,
,FREE_SIZE,INCREMENT_BY,INITIAL_EXTENT,LOGFILES,MAXBYTES,MAX_SIZE,NEXT_EXTENT,PGA_MEMORY,REDO_SIZE,
,SPACE_LIMIT,SPACE_USED,TEMPFILES,TOTAL_SIZE,UNDO_SIZE,BYTES_FREE';
:vtc := ',AVERAGE_WAIT,CPU_TIME,CPU_USED,CUM_WAIT_TIME,DB_TIME,DELTA_TIME,ELAPSED_SECONDS,ELAPSED_TIME,
,IN_WAIT,LAST_RUN_DURATION,RUN_DURATION,SECONDS_IN_WAIT,TIME_REMAINING,TIME_SINCE_LAST_WAIT_MICRO,
,TIME_VALUE,TIME_WAITED,TIME_WAITED_MICRO,TM_DELTA_TIME,UP_TIME,WAIT_TIME,WAIT_TIME_MICRO,LAST_GOOD_DURATION,
,LAST_TRY_DURATION,MEAN_GOOD_DURATION,';
:vnc := ',ACTUAL_ROWS,BLOCKS,BLOCK_CHANGES,BLOCK_GETS,BUFFER_GETS,CALLSPERSEC,CNT,CONSISTENT_CHANGES,
,CONSISTENT_GETS,COST,CPU,CPUPERCALL,DBTIMEPERCALL,DBTIMEPERSEC,DISK_READS,ELAPSEDPERCALL,EXECUTIONS,
,EXTENTS,FAILED_REQ#,FAILURE_COUNT,GETS,HARD_PARSES,INDEXES,L1MS,L1S,L2MS,L2S,L4MS,L4S,L8MS,L8S,L16MS,
,L16S,L32MS,L64MS,L128MS,L256MS,L512MS,LOGICAL_READS,LOGICAL_READ_PCT,METRIC_VALUE,MISSES,NUM_ROWS,
,O16S,OBJECTS,PARSES,PHYSICAL_READS,PHYSICAL_READ_PCT,PHYSICAL_WRITES,ROWS_PROCESSED,RUN_COUNT,
,SEGMENTS,SLEEPS,SOFT_PARSES,STAT_VALUE,SUCC_REQ#,TABLES,TABLESPACES,TOTAL_REQ#,TOTAL_TIMEOUTS,
,TOTAL_WAIT#,TOTAL_WAITS,USER_CALLS,USER_SESSIONS,WAIT_COUNT,DISTINCT_KEYS,BLEVEL,CLUSTERING_FACTOR,
,NUM_NULLS,CACHED_BLOCKS,SEGMENT_BLOCKS,DIRTY_BLOCKS,TEMP_BLOCKS,PING_BLOCKS,STALE_BLOCKS,DIRECT_BLOCKS,
,FORCED_READS,FORCED_WRITES,TOTAL_PCT,CACHED_PCT,LEAF_BLOCKS,
,WAIT_CPU,WAIT_ADM,WAIT_APP,WAIT_CLUS,WAIT_COMMIT,WAIT_CONC,WAIT_CONF,WAIT_IDLE,WAIT_NET,WAIT_OTHER,
,WAIT_SCHED,WAIT_SYS_IO,WAIT_USER_IO,';
end;
/

col ora10 new_val ora10 nopri
col ora11 new_val ora11 nopri
col ora12 new_val ora12 nopri
select
  case when to_number(substr('&&_O_RELEASE', 1, 2))<=10 then '' else '--' end ora10
, case when to_number(substr('&&_O_RELEASE', 1, 2))>=11 then '' else '--' end ora11
, case when to_number(substr('&&_O_RELEASE', 1, 2))>=12 then '' else '--' end ora12
from
  dual
/

col aas for 999
col aas_graph for a40
col account_status for a20
col account_status hea ACCOUNT|STATUS
col actual_analyzed hea ACTUAL|ANALYZED
col actual_rows for a10 hea ACTUAL|ROWS
col additional_info for a30 hea ADDITIONAL|INFO
col allocation_type hea ALLOCATION|TYPE
col argument_name for a20
col attributes for a20 tru
col average_wait for a12  hea AVERAGE|WAIT
col avg_row_len for 9999999 
col bar for a30 
col begin_interval_time for a25
col binst for a5
col blevel for a10
col blevel for a6
col block_changes for a15  hea BLOCK|CHANGES
col block_gets for a15 hea BLOCK|GETS
col block_size for a10 hea BLOCK|SIZE
col blocker for a20
col blocking_instance hea BLOCKING|INSTANCE
col blocking_session hea BLOCKING|SESSION
col blocking_session_status hea BLOCKING|SESSSION|STATUS
col blocks for a10 
col bsid for a5
col buffer_gets for a10 hea BUFFER|GETS
col bytes for a10 
col bytes_free for a10 hea BYTES|FREE
col cached_blocks for a10 hea CACHED|BLOCKS
col cached_pct for a6 hea CACHED_PCT hea CACHED|PCT
col callspersec for a15 
col cf for a6
col client_name for a30
col clustering_factor for a10 hea CLUSTERING|FACTOR
col cnt for a10
col comments for a100
col consistent_changes for a15 hea CONSISTENT|CHANGES
col consistent_gets for a15 hea CONSISTENT|GETS 
col cost for a10 
col cpu for a10
col cpu_time FOR a11 hea CPU|TIME
col cpu_used for a10 hea CPU|USED
col cpupercall for a15
col cum_wait_time for a10 hea cumulative|wait_time
col current_scn for 999999999999999999
col current_timestamp for a35
col currently_used for a10 hea CURRENTLY|USED
col data_object_id for 999999999 hea DATA|OBJECT_ID
col data_type for a20
col database_value for a30 hea DATABASE|VALUE
col datafiles for a10
col db_link for a20
col db_time for a10
col db_unique_name for a10
col dbname for a10
col dbtimepercall for a15 
col dbtimepersec for a15 
col ddl for a180
col default_tablespace for a15 hea DEFAULT|TABLESPACE
col degree for a10
col delta_interconnect_io_bytes for a12 hea DELTA|INTERCONNECT|IO_BYTES
col delta_read_io_bytes for a10 hea DELTA_READ|IO_BYTES
col delta_time for a10
col delta_write_io_bytes for a11 hea DELTA_WRITE|IO_BYTES
col detected_usages hea DETECTED|USAGES
col direct_blocks for a10 hea DIRECT|BLOCKS
col dirty_blocks for a10 hea DIRTY|BLOCKS
col disk_reads for a10  hea DISK|READS
col display_value for a60
col distinct_keys for a10 hea DISTINCT|KEYS
col distinct_keys for a11
col elapsed_seconds for a15 hea ELAPSED|SECONDS
col elapsed_time for a11 hea ELAPSED|TIME 
col elapsedpercall for a15 
col end_interval_time for a25
col eq_name FOR a50
col error# for 99999
col error_count hea ERROR|COUNT
col event for a40 tru
col event_name for a30 tru
col executions for a10 
col expiry_date hea EXPIRY|DATE
col extent_management hea EXTENT|MANAGEMENT
col extents for a10
col failed_req# for a10 hea FAILED|REQ#
col failure_count for a10 hea FAILURE|COUNT
col fetches for a8 
col file_name for a60 
col first_seen for a20 tru
col first_usage hea FIRST|USAGE
col fk for a6
col flashback_on for a14
col flush_elapsed for a20 hea FLUSH|ELAPSED
col forced_reads for a10 hea FORCED|WRITES
col forced_writes for a10 hea FORCED|WRITES
col free_size for a10 hea FREE|SIZE
col gets for a10
col graph for a30 
col h0 for 999
col h1 for 999
col h10 for 999
col h11 for 999
col h12 for 999
col h13 for 999
col h14 for 999
col h15 for 999
col h16 for 999
col h17 for 999
col h18 for 999
col h19 for 999
col h2 for 999
col h20 for 999
col h21 for 999
col h22 for 999
col h23 for 999
col h3 for 999
col h4 for 999
col h5 for 999
col h6 for 999
col h7 for 999
col h8 for 999
col h9 for 999
col hard_parses for a10 hea HARD|PARSES
col hint_name for a30
col holder for a20
col host for a30 tru
col host_name for a12
col idx for a6
col in_out for a6
col in_wait for a8 
col increment_by for a10 hea INCREMENT|BY
col index_name for a40
col index_type for a10
col indexes for a10
col initial_extent for a10 hea INITIAL|EXTENT
col inst_id for 999 hea INST
col instance_name hea INSTANCE|NAME
col instance_number hea INSTANCE|NUMBER
col instance_role hea INSTANCE|ROLE
col instance_value for a30 hea INSTANCE|VALUE
col inverse for a30
col io for a10
col isdefault for a10 hea IS|DEFAULT
col isinstance_modifiable for a10 hea ISINSTANCE|MODIFIABLE
col ismodified for a10 hea IS|MODIFIED
col isses_modifiable for a10 hea ISSES|MODIFIABLE
col issys_modifiable for a10 hea ISSYS|MODIFIABLE
col job_action for a20 tru
col job_name for a40 tru
col job_status for a10
col l128ms for a6 hea "<128ms%"
col l16ms for a6 hea "<16ms%"
col l16s for a6 hea "<16s%"
col l1ms for a6 hea "<1ms%"
col l1s for a6 hea "<1s%"
col l256ms for a6 hea "<256ms%"
col l2ms for a6 hea "<2ms%"
col l2s for a6 hea "<2s%"
col l32ms for a6 hea "<32ms%"
col l4ms for a6 hea "<4ms%"
col l4s for a6 hea "<4s%"
col l512ms for a6 hea "<512ms%"
col l64ms for a6 hea "<64ms%"
col l8ms for a6 hea "<8ms%"
col l8s for a6 hea "<8s%"
col last_analyzed for a15 hea LAST|ANALYZED
col last_ddl_time hea LAST|DDL_TIME
col last_good_date hea LAST_GOOD|DATE
col last_good_duration for a10 hea LAST_GOOD|DURATION
col last_run_duration for a10 hea LAST_RUN|DURATION 
col last_seen for a20 tru
col last_start_date for a14 
col last_try_date hea LAST_TRY|DATE
col last_try_duration for a10 hea LAST_TRY|DURATION
col last_try_result for a10 hea LAST_TRY|RESULT
col last_usage hea LAST|USAGE
col leaf_blocks for a10 hea LEAF|BLOCKS
col lmode for 999
col lmode for a10
col location for a40
col location for a60
col lock_date for a20 hea LOCK|DATE 
col log_date for a14
col log_mode for a12
col logfiles for a10
col logical_read_pct for a10 hea LOGICAL|READ_PCT
col logical_reads for a10 hea LOGICAL|READS
col ltype for a2
col ltype_name for a12
col machine for a16 tru
col max_size for a10 hea MAX|SIZE
col maxbytes for a10
col mean_good_duration for a10 hea MEAN_GOOD|DURATION
col member for a60
col message_group for a11 hea MESSAGE|GROUP
col message_type for a10 hea MESSAGE|TYPE
col metric_name for a60
col metric_unit for a42
col metric_value for a10 hea METRIC|VALUE
col misses for a10 
col mode_held hea MODE|HELD
col mode_requested hea MODE|REQUESTED
col module for a20 tru
col name for a90
col next_extent for a10 hea NEXT|EXTENT
col next_run_date for a14
col num_buckets hea NUM|BUCKETS
col num_nulls for a10
col num_rows for a10 
col o16s for a6 hea ">16s%"
col object_id for 999999999
col object_name for a40
col object_type for a16
col objects for a10
col on_fra for a6
col online_status hea ONLINE|STATUS
col open_mode for a10
col operation_name for a30
col opname for a20 tru
col oracle_username for a15 tru hea oracle|USERNAME
col os_user_name for a15 tru
col owner for a15 tru
col p1text for a10 tru
col p2text for a10 tru
col p3text for a10 tru
col par hea PARA|LLEL
col param_desc for a60
col param_name for a36
col param_type for 9 hea PARAM|TYPE
col parses for a10 
col part for 999
col partition_name for a20
col pct for 999
col pct_max for a4 hea PCT|MAX
col pga_memory for a10 hea PGA|MEMORY
col physical_read_pct for a10 hea PHYSICAL|READ_PCT
col physical_reads for a15 hea PHYSICAL|READS
col physical_writes for a10 hea PHYSICAL|WRITES
col pid for 99999
col ping_blocks for a10 hea PING|BLOCKS
col pk for a6
col plan_hash for a12
col plan_hash_value hea PHV
col plan_source for a10 hea PLAN|SOURCE
col plan_table_output for a179
col platform_name for a20
col plsql for a100
col position for 999
col procedure_name for a30
col process_name for a7 hea PROCESS|NAME
col process_description for a50 hea PROCESS|DESCRIPTION
col profile for a10 tru
col program for a10 tru
col program for a20
col bar for a20
col rac_sid for a20
col reason for a70 
col redo_size for a10
col relative_fno for 9999 hea RELATIVE|FNO
col req_reason for a50
col request for 999
col request for a10
col requesting_session hea REQUESTING|SESSION
col rows_processed for a10 hea ROWS|PROCESSED
col run_count for a10 hea RUN|COUNT
col run_duration for a10 hea RUN|DURATION
col sample_time for a22 tru
col sampled for a7
col schemaname for a10
col scope for a30
col seconds_in_wait for a10 hea SECONDS|IN_WAIT 
col segment_blocks for a10 hea SEGMENT|BLOCKS
col segment_name for a60
col segments for a10 
col serial# for 99999
col service_name for a20
col session_id for a10  
col session_value for a30 hea SESSION|VALUE
col sessiontimezone for a15
col sid for 99999
col slave_pid for a6 hea SLAVE|PID
col sleep_timestamp for a18 hea SLEEP|TIMESTAMP tru
col sleeps for a10 
col snap_level hea SNAP|LEVEL
col snap_time for a25 hea SNAP_TIME
col sofar for a5
col soft_parses for a10 hea SOFT|PARSES
col space_limit for a10 hea SPACE|LIMIT
col space_reclaimable hea SPACE|RECLAIMABLE
col space_used for a10 hea SPACE|USED
col sql_feature for a30
col sql_id for a14 
col sql_text for a80
col sql_text_long for a160
col sql_text_frag for a25 tru  
col stale_blocks for a10 hea STALE|BLOCKS
col startup_time hea STARTUP|TIME
col stat_value for a10
col status for a10
col subpart for 999 hea SUB|PART
col subpartition_count for a4
col subprogram_id for 999 
col succ_req# for a10 hea SUCC|REQ#
col suggested_action for a40 tru hea SUGGESTED|ACTION
col sysdate for a14
col systimestamp for a35
col table_name for a40
col tables for a10 
col tablespace_name for a15 hea TABLESPACE|NAME
col tablespaces for a11
col target for a30
col task_name for a30
col temp_blocks for a10 hea TEMP|BLOCKS
col tempfiles for a10
col temporary_tablespace for a15 hea TEMPORARY|TABLESPACE
col time_remaining for a14 hea TIME|REMAINING
col time_since_last_wait_micro for a15 hea TIME_SINCE|LAST_WAIT_MICRO
col time_suggested for a15 hea TIME|SUGGESTED
col time_value for a10 
col time_waited for a11 
col time_waited_micro for a11 hea TIME|WAITED|MICRO
col total for a10
col total_pct for a5 hea TOTAL|PCT
col total_req# for a10 hea TOTAL|REQ#
col total_size for a10 hea TOTAL|SIZE
col total_timeouts for a10 hea TOTAL|TIMEOUTS
col total_wait# for a10 hea TOTAL|WAIT#
col total_waits for a10 hea TOTAL|WAITS
col totalwork for a9
col trace for 99
col trace_file for a80
col tracefile_identifier for a100 hea TRACEFILE_IDENTIFIER
col ts# for 99
col undo_size for a10
col units for a10
col up_time for a10
col user_calls for a10 hea USER|CALLS
col user_sessions for a13 hea USER|SESSIONS
col username for a15 tru
col version for a10
col wait for a10
col wait_class for a15 tru hea WAIT|CLASS
col wait_count for a10
col wait_event for a20 tru
col wait_time for a10 
col wait_time_micro for a10 hea WAIT_TIME|MICRO 
col uniqueness for a3 tru
col wait_cpu for a6 hea WAIT|CPU
col wait_adm for a6 hea WAIT|ADM
col wait_app for a6 hea WAIT|APP
col wait_clus for a6 hea WAIT|CLUS
col wait_commit for a6 hea WAIT|COMMIT
col wait_conc for a6 hea WAIT|CONC
col wait_conf for a6 hea WAIT|CONF
col wait_idle for a6 hea WAIT|IDLE
col wait_net for a6 hea WAIT|NET
col wait_other for a6 hea WAIT|OTHER
col wait_sched for a6 hea WAIT|SCHED
col wait_sys_io for a6 hea WAIT|SYS_IO
col wait_user_io for a7 hea WAIT|USER_IO
--=

set buf bg
cl buff
i
select 
  p.inst_id
, s.sid
, s.serial#
, to_number(c.spid) pid
, p.name process_name
, p.description process_description
from 
  gv$bgprocess p
, gv$process c
, gv$session s
where 
  p.inst_id=s.inst_id
  and p.inst_id=c.inst_id
  and p.paddr=s.paddr
  and p.paddr=c.addr
order by
  p.inst_id
, p.name
.

set buf bgx
cl buff
i
select 
  d.ksbddidn process_name
, v.ksmfsnam internal_name
, d.ksbdddsc description
from 
  x$ksbdd d
, x$ksbdp p
, x$ksmfsv v
where
  d.indx=p.indx 
  and p.addr=v.ksmfsadr
order by
  1
.

set buf bh
cl buff
i
select
  b.objd object_id
, o.object_type
--, o.owner
, o.owner||'.'||o.object_name||case when o.subobject_name is not null then ':'||o.subobject_name end object_name
, count(b.block#) cached_blocks
, s.blocks segment_blocks
, round((count(b.block#)/s.blocks)*100) cached_pct
, round((count(b.block#)/(select count(*) from v$bh))*100) total_pct
/*
, count(decode(b.status, 'free', 1, '')) s_free
, count(decode(b.status, 'xcur', 1, '')) s_xcur
, count(decode(b.status, 'scur', 1, '')) s_scur
, count(decode(b.status, 'cr', 1, '')) s_cr
, count(decode(b.status, 'read', 1, '')) s_read
, count(decode(b.status, 'mrec', 1, '')) s_mrec
, count(decode(b.status, 'irec', 1, '')) s_irec
*/
, sum(b.forced_reads) forced_reads
, sum(b.forced_writes) forced_writes
, sum(decode(b.dirty, 'Y', 1, 0)) dirty_blocks
, sum(decode(b.temp, 'Y', 1, 0)) temp_blocks
, sum(decode(b.ping, 'Y', 1, 0)) ping_blocks
, sum(decode(b.stale, 'Y', 1, 0)) stale_blocks
, sum(decode(b.direct, 'Y', 1, 0)) direct_blocks
, b.objd id_
from 
  v$bh b
, dba_objects o
, dba_segments s
where
  b.objd=o.data_object_id
  and s.owner=o.owner
  and s.segment_name=o.object_name
  and nvl(s.partition_name, '*')=nvl(o.subobject_name, '*')
  and s.owner not in ('SYS')
group by
  b.objd
, o.object_type
--, o.owner
, o.owner||'.'||o.object_name
, o.subobject_name
, s.blocks
order by
  total_pct desc
.

set buf lock
cl buff
i
select
  s.inst_id
, s.sid
, s.serial#
, s.blocking_instance
, s.blocking_session
, s.blocking_session_status
--, l.addr
, s.module
, s.username
, s.sql_id
--, s.wait_class
--, s.event
&&ORA11, s.wait_time_micro/1e6 wait_time_micro
, l.type lock_type
, decode(l.lmode,0, 'None', 1, 'No Lock', 2, 'Row-S (SS)', 3, 'Row-X (SX)', 4, 'Share', 5, 'S/Row-X (SRX)', 6, 'Exclusive', to_char(l.lmode)) lmode
, decode(l.request, 0, 'None', 1, 'No Lock', 2, 'Row-S (SS)', 3, 'Row-X (SX)', 4, 'Share', 5, 'S/Row-X (SSX)', 6, 'Exclusive', to_char(l.request)) request
--, l.block
, o.object_id
--, o.object_type
--, o.object_name
--, dbms_rowid.rowid_create (1, s.row_wait_obj#, s.row_wait_file#, s.row_wait_block#, s.row_wait_row#) object_rowid
from
  gv$lock l
, gv$session s
, gv$locked_object lo
, dba_objects o
where
  l.inst_id=s.inst_id
  and l.sid=s.sid
  and l.inst_id=lo.inst_id(+)
  and l.sid=lo.session_id(+)
  and lo.object_id=o.object_id
  and l.type in ('TX', 'TM', 'UL')
.

set buf mutex
cl buff
i
select
  m.inst_id
, m.mutex_type
, m.location
, m.sleeps
, m.wait_time/1e6 wait_time
from
  gv$mutex_sleep m
order by
  m.wait_time desc
.

set buf mutexh
cl buff
i
select 
  m.inst_id
, m.sleep_timestamp
--, m.mutex_identifier
, m.mutex_type
, m.location
, m.gets
, m.sleeps
, m.requesting_session
, m.blocking_session
--, m.mutex_value
from
  gv$mutex_sleep_history m
order by
  m.sleep_timestamp desc
.

set buf met
cl buff
i
select
  n.metric_id
, n.metric_name
, n.metric_unit
, n.metric_id id_
from
  v$metricname n
order by 
  n.metric_name
.

set buf alert
cl buff
i
select
  a.instance_number inst_id
, a.message_type
, a.message_group
, a.object_type
, a.reason
, a.suggested_action
, a.time_suggested
from 
  dba_outstanding_alerts a
order by 
  a.creation_time desc
.

set buf at
cl buff
i
select
  t.task_name
, t.operation_name
, t.status
, t.last_good_date
, t.last_good_duration
, t.last_try_date
, t.last_try_result
, t.last_try_duration
, t.mean_good_duration
from
  dba_autotask_task t
order by
  t.task_name
.

set buf lockobj
cl buff
i
select
  l.inst_id
, l.session_id
, l.object_id
, l.oracle_username
, l.os_user_name
, l.process
, l.locked_mode
, o.owner
, o.owner||'.'||o.object_name object_name
, o.object_type
, l.object_id id_
from 
  gv$locked_object l
, dba_objects o 
where 
  o.object_id=o.object_id 
.

set buf job
cl buff
i
select 
  j.owner
, j.owner||'.'||j.job_name job_name
, j.job_type
, substr(j.job_action, 1, 20) job_action
, j.enabled
, j.state
, j.run_count
, j.failure_count
, j.last_start_date
, extract(day from j.last_run_duration)*86400
+ extract(hour from j.last_run_duration)*3600
+ extract(minute from j.last_run_duration)*60
+ extract(second from j.last_run_duration) last_run_duration
, j.next_run_date
--, j.flags
from 
  dba_scheduler_jobs j
order by 
  j.last_start_date desc nulls last
.

set buf jobh
cl buff
i
select
  l.log_id
, d.instance_id inst_id
, l.log_date
, l.owner
, l.owner||'.'||l.job_name job_name
, l.status job_status
, d.error#
, d.session_id 
, d.slave_pid
, extract(day from d.cpu_used)*86400
+ extract(hour from d.cpu_used)*3600
+ extract(minute from d.cpu_used)*60
+ extract(second from d.cpu_used) cpu_used
, extract(day from d.run_duration)*86400
+ extract(hour from d.run_duration)*3600
+ extract(minute from d.run_duration)*60
+ extract(second from d.run_duration) run_duration
, substr(d.additional_info, 1, 40) additional_info
, l.log_id id_ 
from
  dba_scheduler_job_log l
, dba_scheduler_job_run_details d
where
  l.log_id=d.log_id
order by
  l.log_date desc
.

set buf enq
cl buff
i
select 
  e.inst_id
, e.eq_name
, e.eq_type
, e.req_reason
, e.total_req#
, e.total_wait#
, e.succ_req#
, e.failed_req#
, e.cum_wait_time
from 
  gv$enqueue_statistics e
order by
  e.total_req# desc
.

set buf tbs
cl buff
i
select 
  t2.ts#
, t.tablespace_name
, t.bigfile
, t.block_size
--, nvl((select sum(d.bytes) from dba_data_files d where d.tablespace_name=t.tablespace_name),0) total_size
--, nvl((select sum(d.bytes) from dba_free_space d where d.tablespace_name=t.tablespace_name),0) free_size
, d.bytes
, f.bytes_free
, d.maxbytes
, round(d.bytes/d.maxbytes)||'%' pct_max
, t.initial_extent
, t.next_extent
, t.status
, t.contents
, t.logging
, t.extent_management
, t.allocation_type
, t2.ts# id_
from 
  dba_tablespaces t
, v$tablespace t2
, (select f.tablespace_name, sum(f.bytes) bytes, sum(decode(f.autoextensible, 'YES', f.maxbytes,'NO', f.bytes)) maxbytes from dba_data_files f group by tablespace_name
union all select f.tablespace_name, sum(f.bytes) bytes, sum(decode(f.autoextensible, 'YES',f.maxbytes,'NO', f.bytes)) maxbytes from dba_temp_files f group by tablespace_name
) d
, (select f.tablespace_name, sum(f.bytes) bytes_free from dba_free_space f group by f.tablespace_name
union all select f.tablespace_name, sum(f.bytes_free) bytes_free from v$temp_space_header f group by f.tablespace_name) f
where
    t2.name=t.tablespace_name
and t.tablespace_name=d.tablespace_name
and t.tablespace_name=f.tablespace_name
order by
  t.tablespace_name
.

set buf df
cl buff
i
select
  f.relative_fno
, t.ts#
, f.tablespace_name
, f.file_name
, f.status
, f.bytes
, f.maxbytes
, floor((f.bytes/f.maxbytes)*100)||'%' pct_max
, f.increment_by
, f.autoextensible
, f.online_status
, f.file_id id_
from 
  dba_data_files f
, v$tablespace t
where
  f.tablespace_name=t.name
order by
  f.relative_fno
.

set buf col
cl buff
i
select 
  o.object_id
, c.owner
, c.owner||'.'||c.table_name table_name
, c.column_id
, c.column_name
, c.nullable
, c.data_type||'('||c.data_length||case when c.data_type like '%CHAR%' then ' '||decode(c.char_used, 'B', 'BYTE', 'CHAR') else '' end||')' data_type
--, (select wm_concat(q.position) from all_cons_columns q, all_constraints r where q.owner=r.owner and q.constraint_name=r.constraint_name and r.constraint_type='P' and q.column_name=c.column_name and q.owner=c.owner and q.table_name=c.table_name) pk
--, (select wm_concat(q.position) from all_cons_columns q, all_constraints r where q.owner=r.owner and q.constraint_name=r.constraint_name and r.constraint_type='R' and q.column_name=c.column_name and q.owner=c.owner and q.table_name=c.table_name) fk
--, (select wm_concat(q.column_position) from all_ind_columns q where q.column_name=c.column_name and q.table_owner=c.owner and q.table_name=c.table_name) idx
, s.avg_col_len
, s.num_buckets
, s.num_nulls
--, s.density
, o.object_id id_
from 
  all_tab_columns c
, all_tab_col_statistics s
, all_objects o
where
  c.owner=o.owner
  and c.table_name=o.object_name
  and o.object_type='TABLE'
  and c.owner=s.owner
  and c.table_name=s.table_name
  and c.column_name=s.column_name
order by
  c.owner
, c.table_name
, c.column_id
.

set buf sysstat
cl buff
i
select
  s.inst_id
, s.class
, s.statistic#
, n.name stat_name
, s.value stat_value
from
  gv$sysstat s
, v$statname n
where
  s.statistic#=n.statistic#
order by
  s.inst_id
, n.name
.

set buf cnt
cl buff
i
select 
  s.owner
, s.owner||'.'||s.table_name table_name
, s.num_rows
, s.last_analyzed
, to_number(extractvalue(xmltype(dbms_xmlgen.getxml('select count(*) c from "'||s.owner||'"."'||s.table_name||'"')),'/ROWSET/ROW/C')) actual_rows
, sysdate actual_analyzed
from
  all_tables s
where
  s.iot_type is null or s.iot_type!='IOT_OVERFLOW'
order by
  s.owner
, s.table_name
.

set buf ash
cl buff
i
select
  a.inst_id
, a.session_id sid
, a.blocking_session
, a.sample_time
, a.session_serial# serial#
, decode(a.session_type, 'FOREGROUND', 'FG', 'BACKGROUND', 'BG', '?') session_type
&&ORA11, a.is_awr_sample
, a.sql_id
--, a.xid
, a.event event_name
, a.wait_class
, a.time_waited/1e6 time_waited
, a.session_id id_
from 
  gv$active_session_history a
order by 
  a.inst_id
, a.sample_id desc
.

set buf sp
cl buff
i
select
  s.instance_number inst_id
, s.snap_id
, s.snap_time
, s.snap_level
from
  stats$snapshot s
order by
  s.snap_id desc
.

set buf aas
cl buff
i
with t as (select 15 resol from dual)
select
  to_char(trunc(s.sample_time, 'mi')-mod(extract(minute from s.sample_time), resol)/1440, 'YYYY-MM-DD HH24:MI:SS') aas_time
, round(avg(s.on_cpu), 1) on_cpu
, round(avg(s.waiting), 1) waiting
, round(avg(s.aas), 1) aas
, avg(wait_cpu) wait_cpu
, round(avg(wait_administrative), 2) wait_adm
, round(avg(wait_application), 2) wait_app
, round(avg(wait_cluster), 2) wait_clus
, round(avg(wait_commit), 2) wait_commit
, round(avg(wait_concurrency), 2) wait_conc
, round(avg(wait_configuration), 2) wait_conf
, round(avg(wait_idle), 2) wait_idle
, round(avg(wait_network), 2) wait_net
, round(avg(wait_other), 2) wait_other
, round(avg(wait_scheduler), 2) wait_sched
, round(avg(wait_system_io), 2) wait_sys_io
, round(avg(wait_user_io), 2) wait_user_io
, substr(lpad('C', avg(wait_cpu), 'C'),2) || 
  substr(lpad('D', avg(wait_administrative), 'D'),2) || 
  substr(lpad('A', avg(wait_application), 'A'),2) || 
  substr(lpad('L', avg(wait_cluster), 'L'),2) || 
  substr(lpad('M', avg(wait_commit), 'M'),2) || 
  substr(lpad('R', avg(wait_concurrency), 'R'),2) || 
  substr(lpad('F', avg(wait_configuration), 'F'),2) || 
  substr(lpad('I', avg(wait_idle), 'I'),2) || 
  substr(lpad('N', avg(wait_network), 'N'),2) || 
  substr(lpad('O', avg(wait_other), 'O'),2) || 
  substr(lpad('J', avg(wait_scheduler), 'J'),2) || 
  substr(lpad('S', avg(wait_system_io), 'S'),2) || 
  substr(lpad('U', avg(wait_user_io), 'U'),2) aas_graph
from
(
select
  sample_id
, sample_time
, sum(decode(wait_class, 'Administrative', 1, 0)) wait_Administrative
, sum(decode(wait_class, 'Application', 1, 0)) wait_Application
, sum(decode(wait_class, 'Cluster', 1, 0)) wait_Cluster
, sum(decode(wait_class, 'Commit', 1, 0)) wait_Commit
, sum(decode(wait_class, 'Concurrency', 1, 0)) wait_Concurrency
, sum(decode(wait_class, 'Configuration', 1, 0)) wait_Configuration
, sum(decode(wait_class, 'Idle', 1, 0)) wait_Idle
, sum(decode(wait_class, 'Network', 1, 0)) wait_Network
, sum(decode(wait_class, 'Other', 1, 0)) wait_Other
, sum(decode(wait_class, 'Scheduler', 1, 0)) wait_Scheduler
, sum(decode(wait_class, 'System I/O', 1, 0)) wait_System_IO
, sum(decode(wait_class, 'User I/O', 1, 0)) wait_User_IO
, sum(nvl2(wait_class, 0, 1)) wait_cpu
, sum(decode(session_state, 'ON CPU', 1, 0)) on_cpu
, sum(decode(session_state, 'WAITING', 1, 0)) waiting
, count(*) aas
from
  v$active_session_history a
group by 
  a.sample_id
, a.sample_time
) s
, t
group by
   trunc(s.sample_time, 'mi')- mod(extract(minute from s.sample_time), resol)/1440
order by
   trunc(s.sample_time, 'mi')- mod(extract(minute from s.sample_time), resol)/1440 desc
.

--set buf aash
--cl buff
--i
--select 
--  to_char(s.sample_time, 'YYYY-MM-DD') aas_time
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '00', 1, 0)), 1) h0
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '01', 1, 0)), 1) h1
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '02', 1, 0)), 1) h2
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '03', 1, 0)), 1) h3
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '04', 1, 0)), 1) h4
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '05', 1, 0)), 1) h5
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '06', 1, 0)), 1) h6
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '07', 1, 0)), 1) h7
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '08', 1, 0)), 1) h8
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '09', 1, 0)), 1) h9
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '10', 1, 0)), 1) h10
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '11', 1, 0)), 1) h11
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '12', 1, 0)), 1) h12
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '13', 1, 0)), 1) h13
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '14', 1, 0)), 1) h14
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '15', 1, 0)), 1) h15
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '16', 1, 0)), 1) h16
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '17', 1, 0)), 1) h17
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '18', 1, 0)), 1) h18
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '19', 1, 0)), 1) h19
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '20', 1, 0)), 1) h20
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '21', 1, 0)), 1) h21
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '22', 1, 0)), 1) h22
--, round(sum(decode(to_char(s.sample_time, 'hh24'), '23', 1, 0)), 1) h23
--from
--(select sample_id, sample_time, count(*) aas 
--from dba_hist_active_sess_history s group by sample_id, sample_time) s
--group by
--  to_char(s.sample_time, 'YYYY-MM-DD')
--order by
--  to_char(s.sample_time, 'YYYY-MM-DD') desc
--.

set buf awr
cl buff
i
select
  p.dbid
, p.instance_number inst_id
, p.snap_id
, p.snap_level
, p.begin_interval_time
, p.end_interval_time
, p.flush_elapsed
, p.error_count
, p.snap_id id_
from
  dba_hist_snapshot p
order by
  p.instance_number
, p.snap_id desc
.

set buf tpsh
cl buff
i
select
  p.instance_number inst_id
, p.snap_id
, p.begin_interval_time
, p.end_interval_time
, s.value transactions
, round(s.value/(
  extract(hour from p.end_interval_time-p.begin_interval_time)*3600+
  extract(minute from p.end_interval_time-p.begin_interval_time)*60+
  extract(second from p.end_interval_time-p.begin_interval_time)
)) tps
from 
  dba_hist_sysstat s
, dba_hist_snapshot p
where
  s.snap_id=p.snap_id
  and p.instance_number=s.instance_number
  and s.stat_name='user commits'
order by
  p.snap_id desc
.

set buf seswah
cl buff
i
select
  s.inst_id
, s.sid
, s.seq#
, s.event#
, s.event
, s.p1text
, s.p1
, s.p2text
, s.p2
, s.p3text
, s.p3
, s.wait_time
&&ORA11, s.wait_time_micro/1e6 wait_time_micro
&&ORA11, s.time_since_last_wait_micro/1e6 time_since_last_wait_micro
, s.sid id_
from
  gv$session_wait_history s
order by 
  s.inst_id
, s.sid
, s.seq#
&&ORA11, s.time_since_last_wait_micro desc
.

set buf feat
cl buff
i
select
  f.name feature_name
, f.detected_usages
, f.currently_used
, f.first_usage_date first_usage
, f.last_usage_date last_usage
from 
  dba_feature_usage_statistics f
order by
  f.name
.

set buf evhg
cl buff
i
select
  h.inst_id
, n.name event_name
, n.wait_class
, round((max(decode(h.wait_time_milli, 1, h.wait_count, null))/sum(h.wait_count))*100,1) l1ms
, round((max(decode(h.wait_time_milli, 2, h.wait_count, null))/sum(h.wait_count))*100,1) l2ms
, round((max(decode(h.wait_time_milli, 4, h.wait_count, null))/sum(h.wait_count))*100,1) l4ms
, round((max(decode(h.wait_time_milli, 8, h.wait_count, null))/sum(h.wait_count))*100,1) l8ms
, round((max(decode(h.wait_time_milli, 16, h.wait_count, null))/sum(h.wait_count))*100,1) l16ms
, round((max(decode(h.wait_time_milli, 32, h.wait_count, null))/sum(h.wait_count))*100,1) l32ms
, round((max(decode(h.wait_time_milli, 64, h.wait_count, null))/sum(h.wait_count))*100,1) l64ms
, round((max(decode(h.wait_time_milli, 128, h.wait_count, null))/sum(h.wait_count))*100,1) l128ms
, round((max(decode(h.wait_time_milli, 256, h.wait_count, null))/sum(h.wait_count))*100,1) l256ms
, round((max(decode(h.wait_time_milli, 512, h.wait_count, null))/sum(h.wait_count))*100,1) l512ms
, round((max(decode(h.wait_time_milli, 1024, h.wait_count, null))/sum(h.wait_count))*100,1) l1s
, round((max(decode(h.wait_time_milli, 2048, h.wait_count, null))/sum(h.wait_count))*100,1) l2s
, round((max(decode(h.wait_time_milli, 4096, h.wait_count, null))/sum(h.wait_count))*100,1) l4s
, round((max(decode(h.wait_time_milli, 8192, h.wait_count, null))/sum(h.wait_count))*100,1) l8s
, round((max(decode(h.wait_time_milli, 16384, h.wait_count, null))/sum(h.wait_count))*100,1) l16s
, round((max(case when h.wait_time_milli>16384 then h.wait_count else null end)/sum(h.wait_count))*100,1) o16s
, sum(h.wait_count) wait_count
from 
  gv$event_histogram h
, v$event_name n
where
  h.event#=n.event#
group by
  h.inst_id
, n.name
, n.wait_class
order by
  n.name
.

set buf addm
cl buff
i
select 
  dbms_advisor.get_task_report(t.task_name, 'TEXT', 'TYPICAL', 'ALL', t.owner) report
from 
  (select owner, task_name from dba_advisor_tasks where advisor_name='ADDM' order by created desc) t
where
  rownum=1
.

set buf seg
cl buff
i
select
  o.object_id
, o.data_object_id
, s.owner
, s.owner||'.'||s.segment_name segment_name
, s.segment_type
, s.tablespace_name
, s.bytes
, s.blocks
, s.extents
, s.relative_fno
, o.object_id id_
from 
  dba_segments s
, dba_objects o
where
  s.owner=o.owner
  and s.segment_name=o.object_name
  and nvl(s.partition_name, '*')=nvl(o.subobject_name, '*')
order by
  s.owner
, s.segment_name
.

set buf segstat
cl buff
i
select
  s.inst_id
, o.object_id
, o.owner
, o.object_type
, o.owner||'.'||o.object_name object_name
, n.name stat_name
, s.value stat_value
, o.object_id id_
from 
  gv$segstat s
, v$segstat_name n
, dba_objects o
where
  s.statistic#=n.statistic#
  and s.obj#=o.object_id
  and s.dataobj#=o.data_object_id
order by
  s.value desc
.

set buf size
cl buff
i
select
  s.owner
, s.owner||'.'||s.segment_name segment_name
, s.segment_type
, sum(s.blocks) blocks
, sum(s.extents) extents
, sum(s.bytes) bytes
from 
  dba_segments s
, all_objects o
where
  s.owner=o.owner
  and s.segment_name=o.object_name
  and nvl(s.partition_name, '-1')=nvl(o.subobject_name, '-1')
group by
  s.owner
, s.owner||'.'||segment_name
, s.segment_type
order by
  s.owner||'.'||segment_name
.

set buf db
cl buff
i
select
  d.name dbname
, d.log_mode
, d.open_mode
, d.protection_mode
, d.database_role
, d.platform_name
, d.flashback_on
, (select sum(bytes) from dba_data_files) datafiles
, (select sum(bytes) from dba_temp_files) tempfiles
, (select sum(bytes) from v$log) logfiles
, (select count(*) from dba_tablespaces) tablespaces
from
  v$database d
.

set buf stat
cl buff
i
select 
  n.statistic#
, n.name stat_name
, n.statistic# id_
from
  v$statname n
order by
  n.name
.

set buf sesstat
cl buff
i
select
  s.inst_id
, s.sid
, e.module
--, s.statistic#
, n.name stat_name
, s.value stat_value
, s.sid id_
from
  gv$sesstat s
, gv$session e
, v$statname n
where
  s.statistic#=n.statistic#
  and s.inst_id=e.inst_id
  and s.sid=e.sid
--  and e.type='USER'
order by
  s.inst_id
, s.sid
, n.name
.

set buf sesstat2
cl buff
i
select
  s.inst_id
, s.sid
, s.serial#
, s.module
, s.program
, max(decode(n.name, 'redo size', t.value, null)) redo_size
, max(decode(n.name, 'undo change vector size', t.value, null)) undo_size
, max(decode(n.name, 'physical reads', t.value, null)) physical_reads
, max(decode(n.name, 'physical writes', t.value, null)) physical_writes
, max(decode(n.name, 'session logical reads', t.value, null)) logical_reads
, max(decode(n.name, 'user calls', t.value, null)) user_calls
--, max(decode(n.name, 'DB time', t.value/1e3, null)) db_time
, s.sid id_
from 
  gv$session s
, gv$sesstat t
, v$statname n
where
  s.inst_id=t.inst_id
  and s.sid=t.sid
  and t.statistic#=n.statistic#
--  and s.type='USER'
group by
  s.inst_id
, s.sid
, s.serial#
, s.module
, s.program
order by
  redo_size+undo_size+physical_reads+physical_writes+logical_reads desc
.

set buf ddl
cl buff
i
select --1
replace(
dbms_metadata.get_ddl(decode(o.object_type, 
  'DATABASE LINK', 'DB_LINK', 'PACKAGE BODY', 'PACKAGE_BODY', 'TYPE BODY', 'TYPE_BODY', 'MATERIALIZED VIEW', 'MATERIALIZED_VIEW', 
  'MATERIALIZED VIEW LOG', 'MATERIALIZED_VIEW_LOG', o.object_type)
  , o.object_name
  , o.owner), '"', '') ddl
from 
  all_objects o
where 
  o.object_type not in ('LOB', 'EDITION')
  and regexp_like(o.owner||'.'||o.object_name, '&&2', 'i') 
order by 
  o.owner||o.object_name
.

set buf dict
cl buff
i
select 
  d.table_name
, d.comments
, d.table_name id_
from 
  dict d
order by 
  d.table_name
.

set buf dictcol
cl buff
i
select 
  d.table_name
, d.column_name
, d.comments
, d.column_name id_
from 
  dict_columns d
order by 
  d.table_name
, d.column_name
.

set buf inst
cl buff
i
select 
  sysdate
, i.inst_id
, case when i.inst_id=sys_context('userenv', 'instance') then '*' end connected
, i.instance_name
, i.instance_role
, i.host_name
, i.startup_time
, i.status
, i.version
, (select count(*) from gv$session s where s.type='USER' and s.status='ACTIVE' and s.inst_id=i.inst_id) user_sessions
&&ORA11, round((select m.value from v$sysmetric m where m.metric_id=2147 and m.group_id=2), 2) aas
--, 0 tps
, i.inst_id id_
from 
  gv$instance i
order by
  i.inst_id
.

set buf latch
cl buff
i
select 
  l.inst_id
, l.name latch_name
, l.gets
, l.misses
, l.sleeps
, l.wait_time/1e6 wait_time
, l.latch# id_
from 
  gv$latch l
order by 
  l.wait_time desc
.

set buf mystat
cl buff
i
select 
  s.inst_id
, n.name stat_name
, s.value stat_value
, s.statistic# id_
from 
  gv$mystat s
, v$statname n
where 
  s.statistic#=n.statistic# 
  and s.value>0
order by 
  s.inst_id
, s.value desc
.

set buf nls
cl buff
i
select 
  d.parameter
, d.value database_value
, s.value session_value
, i.value instance_value
, '' id_
from 
  nls_database_parameters d
, nls_instance_parameters i
, nls_session_parameters s
where
  d.parameter=i.parameter
  and i.parameter=s.parameter
  and d.parameter=s.parameter
order by 
  d.parameter
.

set buf obj
cl buff
i
select 
  o.object_id
, o.data_object_id
, o.object_type
, o.owner
, o.owner||'.'||o.object_name || case when o.subobject_name is not null then ':'||o.subobject_name else '' end object_name
, o.status
, o.created
, o.last_ddl_time
, o.object_id id_
from 
  dba_objects o
order by
  o.object_type
, o.owner
, o.object_name
.

set buf par
cl buff
i
select 
  p.inst_id
--, p.num
--, p.type param_type
, p.name param_name
, p.display_value
, p.isdefault
--, p.ismodified
--, p.isses_modifiable
--, p.issys_modifiable
--, p.isinstance_modifiable
, p.num id_
from 
  gv$parameter p
--where 
--  p.isdefault='FALSE'
order by 
  p.inst_id
, p.name
.

set buf parx
cl buff
i
select 
  a.ksppinm param_name
, b.ksppstvl session_value
, c.ksppstvl instance_value
, a.ksppdesc param_desc
from 
  x$ksppi a
, x$ksppcv b
, x$ksppsv c
where 
  a.indx=b.indx 
  and a.indx=c.indx
order by 
  a.ksppinm
.

set buf redoh
cl buff
i
select 
  trunc(h.first_time) sw_date
, count(1) sw_per_day
, decode(trunc(first_time), trunc(sysdate), round(count(1) / (24*to_number(to_char(sysdate, 'sssss')+1)/86400),2),
               round(count(1) / 24, 2)) sw_per_hour 
, sum(decode(to_char(h.first_time, 'hh24'), '00', 1, 0)) h0
, sum(decode(to_char(h.first_time, 'hh24'), '01', 1, 0)) h1
, sum(decode(to_char(h.first_time, 'hh24'), '02', 1, 0)) h2
, sum(decode(to_char(h.first_time, 'hh24'), '03', 1, 0)) h3
, sum(decode(to_char(h.first_time, 'hh24'), '04', 1, 0)) h4
, sum(decode(to_char(h.first_time, 'hh24'), '05', 1, 0)) h5
, sum(decode(to_char(h.first_time, 'hh24'), '06', 1, 0)) h6
, sum(decode(to_char(h.first_time, 'hh24'), '07', 1, 0)) h7
, sum(decode(to_char(h.first_time, 'hh24'), '08', 1, 0)) h8
, sum(decode(to_char(h.first_time, 'hh24'), '09', 1, 0)) h9
, sum(decode(to_char(h.first_time, 'hh24'), '10', 1, 0)) h10
, sum(decode(to_char(h.first_time, 'hh24'), '11', 1, 0)) h11
, sum(decode(to_char(h.first_time, 'hh24'), '12', 1, 0)) h12
, sum(decode(to_char(h.first_time, 'hh24'), '13', 1, 0)) h13
, sum(decode(to_char(h.first_time, 'hh24'), '14', 1, 0)) h14
, sum(decode(to_char(h.first_time, 'hh24'), '15', 1, 0)) h15
, sum(decode(to_char(h.first_time, 'hh24'), '16', 1, 0)) h16
, sum(decode(to_char(h.first_time, 'hh24'), '17', 1, 0)) h17
, sum(decode(to_char(h.first_time, 'hh24'), '18', 1, 0)) h18
, sum(decode(to_char(h.first_time, 'hh24'), '19', 1, 0)) h19
, sum(decode(to_char(h.first_time, 'hh24'), '20', 1, 0)) h20
, sum(decode(to_char(h.first_time, 'hh24'), '21', 1, 0)) h21
, sum(decode(to_char(h.first_time, 'hh24'), '22', 1, 0)) h22
, sum(decode(to_char(h.first_time, 'hh24'), '23', 1, 0)) h23
from 
  v$log_history h
group by 
  trunc(h.first_time)
order by
  1 desc
.

set buf scn
cl buff
i
select 
  d.current_scn
from 
  v$database d
.

set buf ses
cl buff
i
select 
  s.inst_id
, s.sid
, s.serial#
, to_number(p.spid) pid
, s.service_name
, s.sql_id
, s.username
, s.status
, s.machine
, s.program
, s.module
, w.event wait_event
&ORA10, w.seconds_in_wait
&ORA11, w.wait_time_micro/1e6 wait_time_micro
--, decode(s.sql_trace,'TRUE',2,0) + decode(s.sql_trace_binds,'TRUE',4,0) + decode(s.sql_trace_waits,'TRUE',8,0) trace
, s.sid id_
from 
  gv$session s
, gv$session_wait w
, gv$process p 
where 
  s.sid=w.sid
  and s.inst_id=w.inst_id
  and s.inst_id=p.inst_id
  and s.paddr=p.addr
--  and s.type='USER'
order by 
&ORA10 w.seconds_in_wait asc
&ORA11 w.wait_time_micro asc
.

set buf sysev
cl buff
i
select 
  e.inst_id
, e.wait_class
, e.event
, e.total_waits
, e.total_timeouts
, e.average_wait/100 average_wait
, e.time_waited_micro/1e6 time_waited_micro
from 
  gv$system_event e
where 
  e.time_waited_micro>0
order by 
  e.time_waited_micro desc
.

set buf sesev
cl buff
i
select 
  e.inst_id
, e.sid
, s.module
--, s.service_name
--, s.username
, e.wait_class
, e.event
, e.total_waits
, e.total_timeouts
, e.average_wait/100 average_wait
, e.time_waited_micro/1e6 time_waited_micro
, e.sid id_
from 
  gv$session_event e
, gv$session s
where 
  s.inst_id=e.inst_id
  and s.sid=e.sid
  and e.time_waited_micro>0
--  and s.type='USER'
order by 
  e.time_waited_micro desc
.

set buf sesio
cl buff
i
select 
  i.inst_id
, i.sid
, s.module
, s.service_name
, s.username
, i.block_gets
, i.consistent_gets
, i.physical_reads
, i.block_changes
, i.consistent_changes
, i.sid id_
from 
  gv$sess_io i
, gv$session s
where 
  i.inst_id=s.inst_id 
  and i.sid=s.sid
--  and s.type='USER'
  and i.block_gets+i.consistent_gets+i.physical_reads+i.block_changes+i.consistent_changes>0
order by 
  i.block_gets+i.consistent_gets+i.physical_reads+i.block_changes+i.consistent_changes desc
.

set buf longops
cl buff
i
select 
  s.inst_id
, s.sid
, s.serial#
, s.sql_id
, e.module
, s.opname
, s.target_desc
, round((s.sofar/s.totalwork)*100) pct
, lpad('.', (s.sofar/s.totalwork)*20, '.') bar
, s.units
, s.time_remaining
, s.elapsed_seconds
, s.sid id_
from 
  gv$session_longops s
, gv$session e
where
  s.time_remaining>0
  and s.sid=e.sid
  and s.serial#=e.serial#
  and s.inst_id=e.inst_id
order by 
  s.sofar/s.totalwork desc
.

set buf sesmet
cl buff
i
select
  m.inst_id
, m.session_id sid
, m.serial_num serial#
, s.module
, m.begin_time
, m.end_time
, m.cpu
, m.physical_reads
, m.logical_reads
, m.pga_memory
, m.hard_parses
, m.soft_parses
, m.physical_read_pct
, m.logical_read_pct
, m.session_id id_
from
  gv$sessmetric m
, gv$session s
where
  m.inst_id=s.inst_id
  and m.session_id=s.sid
--  and s.type='USER'
order by 
  m.inst_id
, m.begin_time desc
.

set buf sestmo
cl buff
i
select 
  m.inst_id
, m.sid
, s.module
, m.stat_name
, m.value/1e6 time_value
, m.sid id_
, m.stat_name search_ 
from 
  gv$sess_time_model m
, gv$session s
where 
  m.value>0
  and m.inst_id=s.inst_id
  and m.sid=s.sid
order by 
  m.value desc 
.

set buf seswa
cl buff
i
select 
  w.inst_id
, w.sid
, w.seq#
, s.service_name
, s.module
, w.event
, w.wait_class
, w.state
&ORA10, w.seconds_in_wait
&ORA11, w.wait_time_micro/1e6 wait_time_micro
, w.sid id_
from 
  gv$session_wait w
, gv$session s
where 
  w.inst_id=s.inst_id 
  and w.sid=s.sid
--  and s.type='USER'
order by 
&ORA10 w.seconds_in_wait desc
&ORA11 w.wait_time_micro desc
.

set buf svc
cl buff
i
select 
  s.inst_id
, s.service_id
, s.name service_name
, s.service_id id_
from 
  gv$services s 
order by 
  s.inst_id
, s.name
.

set buf svcev
cl buff
i
select 
  e.inst_id
, e.service_name
, e.event
, e.average_wait/100 average_wait
, e.time_waited/100 time_waited
from 
  gv$service_event e 
where 
  e.time_waited>0 
  and e.service_name!='SYS$BACKGROUND'
order by 
  e.time_waited desc
.

set buf svcmet
cl buff
i
select 
  m.inst_id
, m.group_id
, m.service_name
, m.elapsedpercall
, m.cpupercall
, m.dbtimepercall
, m.callspersec
, m.dbtimepersec
from 
  gv$servicemetric m
where
  m.group_id=6
  and m.service_name!='SYS$BACKGROUND'
order by 
  m.callspersec desc 
.

set buf svcstat
cl buff
i
select 
  s.inst_id
, s.service_name
, s.stat_name
, s.value stat_value
, s.stat_id id_
from 
  gv$service_stats s
order by 
  s.value desc
.

set buf tab
cl buff
i
select 
  o.object_id
, t.owner
, t.owner||'.'||t.table_name table_name
, t.tablespace_name
, t.status
, t.blocks
, t.avg_row_len
, t.num_rows
, t.last_analyzed
, o.object_id id_
from 
  dba_tables t
, dba_objects o
where 
  t.owner=o.owner 
  and t.table_name=o.object_name 
  and o.object_type='TABLE' 
order by 
  t.owner
, t.table_name
.

set buf proc
cl buff
i
select
  p.object_id
, p.owner
, p.owner||'.'||p.object_name object_name
, p.object_type
--, p.subprogram_id
, p.procedure_name
, a.position
, a.argument_name
, a.in_out
, a.data_type
, p.object_id id_
from 
  all_procedures p
, all_arguments a
where
  p.object_id=a.object_id(+)
  and p.subprogram_id=a.subprogram_id(+)
order by
  p.owner
, p.object_name
, p.subprogram_id
, a.position
.

set buf src
cl buff
i
select
  s.owner
, s.owner||'.'||s.name object_name
, s.type object_type
, s.line
, s.text
from 
  all_source s
order by 
  s.owner
, s.name
, s.type
, s.line
.

set buf idx
cl buff
i
select
  o.object_id
, i.owner||'.'||i.index_name index_name
, i.table_owner||'.'||i.table_name table_name
, i.index_type
, i.uniqueness
, i.tablespace_name
, i.leaf_blocks
, i.distinct_keys
, i.num_rows
, i.clustering_factor
, i.status
, o.object_id id_
from
  all_indexes i
, all_objects o
where
  i.owner=o.owner
  and i.index_name=o.object_name
order by
  i.owner
, i.index_name
.

set buf sid
cl buff
i
select
  i.instance_number inst_id
, s.sid
, s.serial#
, p.spid pid
, s.sid||','||s.serial#||',@'||i.instance_number rac_sid
&&ORA10, (select a.value ||'/'||(select i.instance_name from v$instance i) ||'_ora_'|| (select p.spid||case when p.traceid is not null then '_'||p.traceid else null end from v$process p where p.addr = (select s.paddr from v$session s where sid = (select max(m.sid) from v$mystat m) ) ) || '.trc' tracefile from v$parameter a where a.name='user_dump_dest') trace_file
&&ORA11, (select value from v$diag_info where name='Default Trace File') trace_file
from 
  v$session s
, v$instance i
, v$process p
where
  s.sid=(select sid from v$mystat where rownum=1)
  and s.paddr=p.addr
.

set buf sql_
cl buff
i
select
  s.inst_id
, s.service service_name
, s.sql_id
, s.plan_hash_value
, s.module
, s.executions 
, s.parse_calls parses
, s.disk_reads 
, s.buffer_gets 
, s.rows_processed
, s.elapsed_time/1e6 elapsed_time
, s.cpu_time/1e6 cpu_time
, s.optimizer_cost cost
, s.sql_id id_
from 
  gv$sql s
order by 
  s.elapsed_time desc
.

set buf txt
cl buff
i
select
  s.inst_id
, s.sql_id
, regexp_replace(substr(s.sql_text, 1, 160), '\s+', ' ') sql_text_long
from
  gv$sql s
order by
  s.elapsed_time desc
.

set buf txt1
cl buff
i
select unique --1
  t.piece
, t.sql_text
from 
  gv$sqltext t
where
  t.sql_id='&&2'
order by
  t.piece
.

set buf txt1h 
cl buff
i
select --1
 t.sql_text
from
  dba_hist_sqltext t
where
  t.sql_id='&&2'
.

set buf plans
cl buff
i
select 
  'CACHE' plan_source
, p.sql_id
, p.plan_hash_value
, min(to_date(p.first_load_time, 'YYYY-MM-DD/HH24:MI:SS')) first_seen
, max(to_date(p.last_active_time)) last_seen
--, to_char(substr(p.sql_text, 1, 30)) sql_text 
from 
  gv$sqlarea p
where
  p.sql_id='&&2'
group by
  p.sql_id
, p.plan_hash_value
--, to_char(substr(p.sql_text, 1, 30))
union all
select 
  'AWR'
, h.sql_id
, h.plan_hash_value
, min(s.begin_interval_time)
, max(s.end_interval_time)
--, to_char(substr(t.sql_text, 1, 30))
from 
  dba_hist_sqlstat h
, dba_hist_sql_plan p
, dba_hist_snapshot s
--, dba_hist_sqltext t
where 
  h.snap_id=s.snap_id
  and h.dbid=p.dbid
  and h.sql_id=p.sql_id
  and h.sql_id='&&2'
--  and t.sql_id=h.sql_id
group by 
  h.sql_id
, h.plan_hash_value
--, to_char(substr(t.sql_text, 1, 30))
union all
select 
  'SQLSET'
, p.sql_id
, p.plan_hash_value
, p.plan_timestamp
, p.plan_timestamp
--, to_char(p.sql_text) 
from 
  dba_sqlset_statements p
where
  p.sql_id='&&2'
.

set buf plan
cl buff
i
select --1
  t.plan_table_output
from 
  table(dbms_xplan.display_cursor('&&2', '', 'last')) t
.

set buf planh
cl buff
i
select --1
  t.plan_table_output 
from
  table(dbms_xplan.display_awr('&&2')) t
.

set buf plana
cl buff
i
select --1
  t.plan_table_output 
from
  table(dbms_xplan.display_cursor('&&2', '', 'advanced rows bytes cost last')) t
.

set buf sysmet
cl buff
i
select 
  m.inst_id
, m.metric_id
, m.metric_name
, m.value metric_value
, m.metric_unit
, m.metric_id id_
from 
  gv$sysmetric m 
where 
  m.group_id=2
order by 
  m.inst_id
, m.metric_name
.

set buf systmo
cl buff
i
select 
  m.inst_id
, m.stat_name
, m.value/1e6 time_value
from 
  gv$sys_time_model m
where 
  m.value>0
order by 
  m.value desc 
.

set buf uptime
cl buff
i
select 
  s.inst_id
, extract(second from numtodsinterval(sysdate-s.logon_time, 'second'))*1440*60 up_time
, s.logon_time up_since
, s.sid id_
from 
  gv$session s
where 
  s.program like '%(PMON)%'
order by
  s.inst_id
.

set buf usr
cl buff
i
select 
  u.user_id
, u.username
, u.account_status
, u.lock_date
, u.expiry_date
, u.default_tablespace
, u.temporary_tablespace
, u.created
, u.profile
, u.user_id id_
from 
  dba_users u
order by 
  u.username
.

set buf ashh
cl buff
i
select 
  h.snap_id
, h.instance_number inst_id
, h.sample_time
, h.session_id sid
, h.session_serial# serial#
, h.sql_id
, h.session_state
, h.event event_name
, h.wait_time
, h.module
, h.session_id id_
from 
  dba_hist_active_sess_history h
, v$database d
where
  d.dbid=h.dbid
  and h.session_type='FOREGROUND'
order by
  h.snap_id desc
.

--- Do Not Edit Below This Line -----------------------------------------------

def bxv=1.0
var sql clob
var run clob
var rc refcursor

col id_ nopri
col rn_ nopri

col dtf new_val dtf nopri
col dtr new_val dtr nopri
col dts new_val dts nopri
col buf new_val buf nopri

with t as (select case when regexp_like(sys_context('userenv', 'module'), 'SQL\*Plus|sqlplus\.exe') then 'win' else 'nix' end plat from dual)
select
  decode(plat, 'win', '%TEMP%\blackbox.', '/tmp/blackbox.')||dbms_random.string('x',8) dtf
, decode(plat, 'win', 'del', 'rm') dtr
, decode(plat, 'win', '1>nul 2>nul', '2>/dev/null') dts
, regexp_replace(nvl(substr(q'[&&1]', 1, instr(q'[&&1]', ';')-1), q'[&&1]'), '^sql$', 'sql_') buf
from
  t
/

cl buff
set buf "&&buf"
sav &&dtf
@&&dtf
.
0 begin :sql := q'{
999 }'; end;;
/

ho &&dtr &&dtf &&dts

declare
  -- This Is Blackbox
  -- by Przemyslaw Piotrowski
  type llt is table of varchar2(100) index by varchar2(1); 
  lla llt;
  lst varchar2(32000) := :sql;
  lsq int default dbms_sql.open_cursor;
  lds dbms_sql.desc_tab;
  lcn number;
  lcs varchar2(32000);
  lcf varchar2(32000);
  lco varchar2(10000);
  laa varchar2(6000);
  lab varchar2(6000);
  function arg(a varchar2) return varchar2 is begin return substr(regexp_substr(q'[&&1]', ';'||a||'=([^;]+)', 1, 1), 4); end;
  procedure d(a varchar2, b varchar2, fi boolean := true) is begin if fi then lst := a || lst || b; end if; end;
  procedure stp(a varchar2, b boolean) is begin dbms_metadata.set_transform_param(dbms_metadata.session_transform, a, b); end;
  function rep(a varchar2, b varchar2, c varchar2) return varchar2 is begin return regexp_replace(a, b, c); end;
  function typ(a varchar2) return varchar2 is begin return case when instr(','||:vsc||',', ','||a||',')>0 then 's' 
             when instr(','||:vtc||',', ','||a||',')>0 then 't' when instr(','||:vnc||',', ','||a||',')>0 then 'n' end; end;
  function sub(a varchar2, b varchar2, c number := 1) return varchar2 is begin return regexp_substr(a, '[^'||b||']+', 1, c); end;
begin
  lla('_') := q'{&&buf}';
  for i in (select * from table(sys.odcivarchar2list('c', 's', 'h', 'i', 'n', 't', 'w', 'g'))) loop
    lla(i.column_value) := arg(i.column_value);
  end loop;

  if lower(lla('_')) like 'select %' then
    lst := q'{&&buf}';
  elsif lst in (chr(10),chr(13)) or lst is null then
    lst := q'{select * from &&buf}';
  end if;

  dbms_sql.parse(lsq, lst, dbms_sql.native);
  dbms_sql.describe_columns(lsq, lcn, lds);
  for i in 1..lcn loop
    lco := lds(i).col_name;
    if lds(i).col_type!=8 then
      if substr(lco, -1)!='_' then
        lcf := lcf || chr(10) || '"' || lco || '"' || '||'';''' || case when i<lcn then '||' end;
      end if;
      lco := '"' || lco || '"';
      lco := case lds(i).col_type
        when 8 then 'to_lob('||lco||') '||lco
        when 12 then 'to_char('||lco||',''mm/dd/yy hh24:mi'') '||lco
        when 181 then 'to_char('||lco||' at time zone sessiontimezone,''mm/dd/yy hh24:mi'') '||lco
        else lco 
      end;
      if lla('h')='n' then
        lco := 'to_char('||lco||') '||lco;
      elsif (lla('c') is null or not regexp_like(lla('c'), '(sum|count|avg)\(+')) then
        lco := case typ(trim('"' from lco))
        when 's' then ' nvl((select round('||lco||'/n,1)||u from (select power(1024,rownum-1) n,column_value u from table(sys.odcivarchar2list(''b'',''kb'',''mb'',''gb'',''tb'',''pb'',''eb'',''zb'',''yb'')) order by -n) where floor('||lco||'/n)>0 and rownum=1),0) '||lco
        when 't' then ' nvl((select unique first_value(round('||lco||'/tn.s,1)||ts.s) over (order by tn.s desc) from (select rownum n, column_value s from table(sys.dbms_debug_vc2coll(''us'',''ms'',''s'',''mi'',''h'',''d'',''w'',''mo'',''y'',''c''))) ts, '
            ||chr(10)||'(select rownum n, column_value s from table(sys.odcinumberlist(1/1e6,1/1e3,1,60,3600,86400,604800,2592e3,31536e3,31536e5))) tn where ts.n=tn.n and floor('||lco||'/tn.s)>0),0) '||lco
        when 'n' then ' nvl((select round('||lco||'/n,1)||u from (select power(1e3,rownum-1) n,column_value u from table(sys.odcivarchar2list('''',''k'',''m'',''b'',''t'')) order by -n) where floor('||lco||'/n)>0 and rownum=1),0) '||lco
        else lco
        end;
      end if;
    end if;
    lcs := lcs || lco || case when i<lcn then ',' end;
  end loop;
  dbms_sql.close_cursor(lsq);
  d('select t.* from (', ') t order by '||lla('s')||' nulls last', lla('s') is not null and lla('c') is null);

  if lst not like '%--1%' then
    lab := nvl(replace(replace(q'[&&2]', '..', '\.'), '%', '.*?'), '.*');
    if substr(lab, 1, 1)='=' or substr(lab, 1, 7)='select ' or lab='~' then
      if lab='~' then
        lab := '(select max(sid) from v$session where audsid=sys_context(''userenv'', ''sessionid'') and inst_id=sys_context(''userenv'', ''instance''))';
      end if;
      laa := 't.id_ in (' || trim('=' from lab) || ')';
    else
      laa := case when lab like '!%' then 'not' end ||' regexp_like('||lcf||''''',  trim(''!'' from q''[' ||lab||']''), ''i'')';    
  --    laa := 'lower('||lcf ||''''')' || case when q'{&&2}' like '!%' then 'NOT' end ||' like ''%' ||replace(q'{&&2}', '''', '''''')||'%''';
    end if;
    d('select t.* from (', ') t where '|| laa);
  end if;

  d('select t.* from (', ') t where '||lla('w'), lla('w') is not null);
  d('select t.* from (', ') t where inst_id in ('||lla('i')||')', lla('i') is not null); 

  if lla('n') is not null then
    if instr(lla('n'),'/')>0 then
      d(rep(lla('n'), '(\d+)/([^/]+)/(.+)', 'select t.*, row_number() over (partition by \2 order by \3) rn_ from ('), ') t ');
      d('select t.* from (', ') t where rn_<='||sub(lla('n'),'/',1));
    else
      d('select t.* from (', ') t where rownum<='||lla('n'));
    end if;
  end if;

  if lla('t') is not null and instr(lower(lst), 'snap_id')>0 then
    laa := sub(lla('t'), ':', 1);
    lab := sub(lla('t'), ':', 2);
    if regexp_like(lla('t'), '[a-z]') then
      select regexp_replace(laa, '-(\d+)([a-z]+)?', '\1*'||decode(regexp_substr(laa, '[a-z]+'),'w','7','d','1','h','1/24','mi','24/60','s','24/60/60')),
      regexp_replace(lab, '-(\d+)([a-z]+)?', '\1*'||decode(regexp_substr(lab, '[a-z]+'),'w','7','d','1','h','1/24','mi','24/60','s','24/60/60')) into laa, lab from dual;
      d('select (select begin_interval_time from dba_hist_snapshot p where p.snap_id=t.snap_id) snap_time, t.* from (', ') t where (select begin_interval_time from dba_hist_snapshot p where p.snap_id=t.snap_id) between sysdate-'||nvl(laa, 99999)||' and sysdate-'||nvl(lab,0));
    else
      d('select (select begin_interval_time from dba_hist_snapshot p where p.snap_id=t.snap_id) snap_time, t.* from (', ') t where snap_id between '||nvl(laa, 0)||' and '||nvl(lab,9e9) ||' order by snap_id desc');
    end if;
    lcs := 'SNAP_TIME,'||lcs;
  end if;

  if lla('g') is not null then
    for i in (
      select regexp_replace(xmlagg(xmlelement("a", 'lpad('||level||',10*'||regexp_substr(lla('g'), '(\w+)', 1, level)||'/sum('||regexp_substr(lla('g'), '(\w+)', 1, level)||')over(), '||level||')'||'||') order by 1).extract('//text()'), '\|\|$', '') g 
      from dual connect by level<instr(','||lla('g'), ',', 1, level)
    ) loop
    d('select t.*, substr('||i.g||',1) graph from (', ') t');
    lcs := lcs || ',GRAPH';
    end loop;
  end if;

  d('select '||lcs||' from (', ') t');
 
  if lla('c') is not null then
    if regexp_like(lla('c'), '.+?(sum|count|avg)\(') then
      lcn := regexp_instr(lla('c'), ',(sum|count|avg)\((.+)\)');
      d('select '||lla('c')||' from (', ') t group by '||substr(lla('c'), 1, lcn-1)); 
    else
      d('select '||case when lla('c') like '*%' then 'unique ' end || trim('*' from lla('c'))||' from (', ') t', lla('c') is not null);
    end if;
    d('select t.* from (', ') t order by '||lla('s')||' nulls last', lla('s') is not null);
  end if;

  <<eof>>
--  dbms_output.put_line(lst);

  :sql := lst;
  open :rc for lst;

  if q'{&&buf}'='ddl' then
    stp('SQLTERMINATOR', true);
    stp('PRETTY', true);
    stp('SEGMENT_ATTRIBUTES', true);
  end if;

  exception when others then if sqlcode in (-22922) then null; else raise; end if;
end;
/

set term on
print rc
cl col
--- Blackbox Ends Here --------------------------------------------------------
