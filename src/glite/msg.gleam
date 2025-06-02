import gleam/erlang/process.{type Subject}

// -----------------------------------
// request to service from client
// Causes the service to spawn a new handler and 
// pass on the client subject.
pub type ServiceRequest(a) {
  SReq(sender_subject: CReqS(a))
}

pub type SReqS(a) =
  Subject(ServiceRequest(a))

// -----------------------------------
// request to client from handler
pub type ClientRequest(a) {
  CReq(handler_subject: CRespS(a), request: a)
  SelfReq(a)
}

pub type CReqS(a) =
  Subject(ClientRequest(a))

// response from client to handler
pub type ClientResponse(a) {
  CResp(resp: a)
}

pub type CRespS(a) =
  Subject(ClientResponse(a))
