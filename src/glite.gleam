//// Supervisor starts one service, three client processes and also a
//// one_for_one supervisor.
//// 
//// Clients send two requests each to service with subjects for receiving
//// request from "handlers"
//// 
//// The service process requests the "one_to_one" supervisor to start
//// handler processes and passes on the service handler req subject.
//// 
//// The handlers sends req to clients and includes a response subject.
//// Client responds with (authentication) string which is wrong.
//// Counter is increased and handler reqest new authentication string.
//// When the counter exceeds 3 handler responds with error string and terminates.
////
//// If the service process receives more than 9 requests to start handlers it
//// will exit (panic). Just a hardcoded limit to test the one_for_all restart.

import gleam
import gleam/erlang/process
import gleam/io
import gleam/otp/actor
import gleam/otp/static_supervisor as sup
import gleam/otp/supervision
import glite/client
import glite/service

/// Gleam run makes sure that all registered applications are started,
/// so the main function will just sleep forever.
/// Check gleam.toml to see the start module in the [erlang] section:
///
/// application_start_module = "\<thismodule>\"
/// which in this case is `glite_app`.
pub fn main() {
  io.println("Hello from gliteapp!")
  observer_start()
  process.sleep_forever()
}

type ErlangResult

@external(erlang, "observer", "start")
fn observer_start() -> ErlangResult

// --------------------- Erlang/OTP Application part --------------------
/// The Erlang/OTP application start.
/// Responsible to start the "top" supervisor process and return its Pid
/// to the application controller. Called from glite_app.erl.
pub fn start_link() -> Result(process.Pid, actor.StartError) {
  io.println("Application start - starts the top supervisor")
  case start_supervisor() {
    Ok(actor.Started(pid, _data)) -> {
      let sup_name = process.new_name("one_for_all_sup")
      let _ = process.register(pid, sup_name)
      Ok(pid)
    }
    Error(reason) -> Error(reason)
  }
}

// -------- Supervisor ----------------------------------
/// Erlang application top supervisor
fn start_supervisor() {
  let sub_sup_name = process.new_name("one_for_one_sup")
  let service_name = process.new_name("glite_service")
  let service_subject = process.named_subject(service_name)
  let service_child =
    supervision.worker(fn() {
      gleam.Ok(actor.Started(
        service.start_link(sub_sup_name, service_name),
        service_subject,
      ))
    })
  let client_child =
    supervision.worker(fn() {
      gleam.Ok(actor.Started(client.start_link(service_subject), Nil))
    })

  let one_for_one_sup =
    supervision.worker(fn() {
      let assert Ok(actor.Started(pid, _)) = sup.new(sup.OneForOne) |> sup.start
      case process.register(pid, sub_sup_name) {
        Ok(Nil) -> gleam.Ok(actor.Started(pid, Nil))
        Error(Nil) -> Error(actor.InitFailed("Supervisor name already exist"))
      }
    })
  sup.new(sup.OneForAll)
  |> sup.add(one_for_one_sup)
  |> sup.add(service_child)
  |> sup.add(client_child)
  |> sup.add(client_child)
  |> sup.add(client_child)
  |> sup.start
}
