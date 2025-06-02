import gleam/erlang/process
import gleam/io
import gleam/otp/actor
import gleam/string
import glite/child
import glite/handler
import glite/msg.{type SReqS}

type State {
  State(sup_name: process.Name(String), my_subject: SReqS(String), no_reqs: Int)
}

pub fn start_link(
  sup_name: process.Name(String),
  name: process.Name(msg.ServiceRequest(String)),
) -> process.Pid {
  let servsub = process.named_subject(name)
  let initialiser = fn(_subject: SReqS(String)) {
    let selector = process.new_selector() |> process.select(servsub)
    let state = State(sup_name: sup_name, my_subject: servsub, no_reqs: 0)
    actor.initialised(state)
    |> actor.selecting(selector)
    |> actor.returning(servsub)
  }

  let assert Ok(actor.Started(pid, _data)) =
    actor.new_with_initialiser(1000, fn(subject) { Ok(initialiser(subject)) })
    |> actor.on_message(loop)
    |> actor.start()

  let _ = process.register(pid, name)
  pid
}

fn loop(state: State, msg) {
  case msg, state.no_reqs {
    msg.SReq(sender_subject), x if x < 10 -> {
      case handler.start(state.sup_name, sender_subject) {
        Ok(child.SupervisedChild(pid, _id)) -> {
          let reply = "Starting handler " <> string.inspect(pid)
          io.println(reply)
        }
        Error(e) -> {
          let reply = "Supervisor could not start handler" <> string.inspect(e)
          panic as reply
        }
      }
    }
    _, _ -> panic as "Service panic due to reqs > 9 - restarting"
  }
  actor.continue(State(..state, no_reqs: state.no_reqs + 1))
}
