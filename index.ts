import {createClient} from "https://esm.sh/@supabase/supabase-js@2";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
const json=(body:any,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json"}});
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 if(req.method!=="POST")return json({error:"Method not allowed"},405);
 try{
  const {slug,name,email}=await req.json();
  if(typeof slug!=="string"||typeof name!=="string"||typeof email!=="string"||name.trim().length<2||name.length>100||email.length>254||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))return json({error:"Enter a valid name and email."},400);
  const db=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const {data:exam,error:ee}=await db.from("exams").select("id,title,duration_seconds,positive_marks,negative_marks").eq("slug",slug).eq("published",true).single();
  if(ee||!exam)return json({error:"This examination is not currently available."},404);
  const {data:candidate,error:ce}=await db.from("candidates").insert({full_name:name.trim(),email:email.trim().toLowerCase()}).select("id").single();
  if(ce)throw ce;
  const {data:attempt,error:ae}=await db.from("attempts").insert({exam_id:exam.id,candidate_id:candidate.id}).select("id").single();
  if(ae)throw ae;
  const {data:questions,error:qe}=await db.from("questions").select("id,position,prompt,prompt_bn,options,options_bn").eq("exam_id",exam.id).order("position");
  if(qe)throw qe;
  if(!questions?.length)return json({error:"The exam has no questions yet."},409);
  return json({exam,attempt_id:attempt.id,questions,duration_seconds:exam.duration_seconds});
 }catch(e){console.error(e);return json({error:"Unable to start the examination. Please try again."},500);}
});
