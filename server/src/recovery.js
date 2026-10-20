import { transaction } from './db.js';
import { newToken, hashToken, hashPassword, text, fail } from './security.js';

export async function issueRecoveryToken(db, login) {
  login = text(login,'login',254).toLowerCase();
  return transaction(db,async()=>{
    await db.exec('SELECT pg_advisory_xact_lock(62700323)');
    const user=await db.prepare('SELECT id FROM users WHERE login=?').get(login);
    if(!user)fail(404,'recovery_account_unavailable');
    const token=newToken(),expiresAt=Date.now()+15*60*1000;
    await db.prepare('DELETE FROM password_resets WHERE user_id=?').run(user.id);
    await db.prepare('INSERT INTO password_resets(token_hash,user_id,expires_at) VALUES(?,?,?)').run(hashToken(token),user.id,expiresAt);
    return {token,expiresAt};
  });
}
export async function resetPassword(db, input) {
  if(typeof input.token!=='string'||!/^[A-Za-z0-9_-]{43}$/.test(input.token))fail(400,'invalid_recovery_token');
  if(typeof input.password!=='string'||input.password.length<12||input.password.length>256)fail(400,'password_length_12_to_256');
  const password=await hashPassword(input.password);
  return transaction(db,async()=>{
    await db.exec('SELECT pg_advisory_xact_lock(62700323)');
    const reset=await db.prepare('SELECT * FROM password_resets WHERE token_hash=? FOR UPDATE').get(hashToken(input.token));
    if(!reset||reset.used_at!==null||reset.expires_at<=Date.now())fail(400,'invalid_recovery_token');
    await db.prepare('UPDATE users SET password=? WHERE id=?').run(password,reset.user_id);
    await db.prepare('DELETE FROM sessions WHERE user_id=?').run(reset.user_id);
    await db.prepare('UPDATE password_resets SET used_at=? WHERE token_hash=?').run(Date.now(),reset.token_hash);
    return {ok:true,reauthenticationRequired:true};
  });
}
