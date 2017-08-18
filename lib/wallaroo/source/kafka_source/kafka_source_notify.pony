use "collections"
use "pony-kafka"
use "time"
use "sendence/guid"
use "wallaroo/boundary"
use "wallaroo/core"
use "wallaroo/fail"
use "wallaroo/metrics"
use "wallaroo/recovery"
use "wallaroo/source"
use "wallaroo/topology"

primitive KafkaSourceNotifyBuilder[In: Any val]
  fun apply(pipeline_name: String, auth: AmbientAuth,
    handler: SourceHandler[In] val,
    runner_builder: RunnerBuilder, router: Router,
    metrics_reporter: MetricsReporter iso, event_log: EventLog,
    target_router: Router, pre_state_target_id: (U128 | None) = None):
    SourceNotify iso^
  =>
    KafkaSourceNotify[In](pipeline_name, auth, handler, runner_builder, router,
      consume metrics_reporter, event_log, target_router, pre_state_target_id)

class KafkaSourceNotify[In: Any val]
  let _guid_gen: GuidGenerator = GuidGenerator
  let _pipeline_name: String
  let _source_name: String
  let _handler: SourceHandler[In] val
  let _runner: Runner
  var _router: Router
  let _omni_router: OmniRouter = EmptyOmniRouter
  let _metrics_reporter: MetricsReporter

  new iso create(pipeline_name: String, auth: AmbientAuth,
    handler: SourceHandler[In] val,
    runner_builder: RunnerBuilder, router: Router,
    metrics_reporter: MetricsReporter iso, event_log: EventLog,
    target_router: Router, pre_state_target_id: (U128 | None) = None)
  =>
    _pipeline_name = pipeline_name
    _source_name = pipeline_name + " source"
    _handler = handler
    _runner = runner_builder(event_log, auth, None,
      target_router, pre_state_target_id)
    _router = _runner.clone_router_and_set_input_type(router)
    _metrics_reporter = consume metrics_reporter

  fun routes(): Array[Consumer] val =>
    _router.routes()

  fun ref received(src: KafkaSource[In] ref, msg: KafkaMessage val,
    network_received_timestamp: U64)
  =>
    let ingest_ts = Time.nanos()
    let pipeline_time_spent: U64 = 0
    var latest_metrics_id: U16 = 1

    ifdef "detailed-metrics" then
      _metrics_reporter.step_metric(_pipeline_name,
        "Kafka Client decode time (before wallaroo)", latest_metrics_id,
        network_received_timestamp, ingest_ts)
      latest_metrics_id = latest_metrics_id + 1
    end

    let data = msg.get_value()

    ifdef "trace" then
      @printf[I32](("Rcvd msg at " + _pipeline_name + " source\n").cstring())
    end

    (let is_finished, let keep_sending, let last_ts) =
      try
        src.next_sequence_id()
        let decoded =
          try
            _handler.decode(consume data)
          else
            ifdef debug then
              @printf[I32]("Error decoding message at source\n".cstring())
            end
            error
          end
        let decode_end_ts = Time.nanos()
        _metrics_reporter.step_metric(_pipeline_name,
          "Decode Time in Kafka Source", latest_metrics_id, ingest_ts,
          decode_end_ts)
        latest_metrics_id = latest_metrics_id + 1

        ifdef "trace" then
          @printf[I32](("Msg decoded at " + _pipeline_name +
            " source\n").cstring())
        end
        _runner.run[In](_pipeline_name, pipeline_time_spent, decoded,
          src, _router, _omni_router, _guid_gen.u128(), None,
          decode_end_ts, latest_metrics_id, ingest_ts, _metrics_reporter)
      else
        @printf[I32](("Unable to decode message at " + _pipeline_name +
          " source\n").cstring())
        ifdef debug then
          Fail()
        end
        (true, true, ingest_ts)
      end

    if is_finished then
      let end_ts = Time.nanos()
      let time_spent = end_ts - ingest_ts

      ifdef "detailed-metrics" then
        _metrics_reporter.step_metric(_pipeline_name,
          "Before end at Kafka Source", 9999,
          last_ts, end_ts)
      end

      _metrics_reporter.pipeline_metric(_pipeline_name, time_spent +
        pipeline_time_spent)
      _metrics_reporter.worker_metric(_pipeline_name, time_spent)
    end

  fun ref update_router(router: Router) =>
    _router = router

  fun ref update_boundaries(obs: box->Map[String, OutgoingBoundary]) =>
    match _router
    | let p_router: PartitionRouter =>
      _router = p_router.update_boundaries(obs)
    else
      ifdef debug then
        @printf[I32](("KafkaSourceNotify doesn't have PartitionRouter. " +
          "Updating boundaries is a noop for this kind of Source.\n").cstring())
      end
    end
